// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// The affinity kind-switch lives here, at the unified vocabulary's own home:
// the platform `apply(_:)` surfaces this file used to dispatch into were
// deleted by their owners (swift-foundations/swift-linux#4,
// swift-foundations/swift-windows#2), because a platform L2/L3-policy layer
// cannot take the L3 unifier's `Kernel.Thread.Affinity` as a parameter. What
// remains platform-owned is the mechanism — `setMask(cores:)` and NUMA
// topology discovery — which this file composes behind kernel's own typed
// error mapping.
#if os(Linux)
    internal import Linux_Kernel_System_Standard
    internal import System_Primitives
#elseif os(Windows)
    internal import System_Primitives
    internal import Windows_32_Kernel_System
    internal import Windows_32_Kernel_Thread
#endif

extension Kernel.Thread.Affinity {
    /// Platform support level for thread affinity.
    ///
    /// - Linux: `.enforced` — pthread_setaffinity_np pins threads
    /// - Windows: `.enforced` — SetThreadAffinityMask pins threads
    /// - Darwin: `.none` — macOS/iOS don't support thread affinity
    ///
    /// ## Usage
    /// ```swift
    /// switch Kernel.Thread.Affinity.support {
    /// case .none:
    ///     print("Affinity not supported")
    /// case .advisory:
    ///     print("Affinity is best-effort")
    /// case .enforced:
    ///     print("Affinity will be honored")
    /// }
    /// ```
    public static var support: Support {
        #if os(Linux)
            .enforced
        #elseif os(Windows)
            .enforced
        #else
            .none
        #endif
    }

    /// Applies affinity to the current thread.
    ///
    /// ## Platform Behavior
    /// - Linux: Uses pthread_setaffinity_np
    /// - Windows: Uses SetThreadAffinityMask
    /// - Darwin: Throws `.unsupported` for non-`.any` affinity
    ///
    /// ## Usage
    /// ```swift
    /// try Kernel.Thread.Affinity.apply(.cores([0, 1, 2, 3]))
    /// ```
    ///
    /// - Parameter affinity: The affinity specification.
    /// - Throws: `Kernel.Thread.Affinity.Error` on failure.
    public static func apply(
        _ affinity: Kernel.Thread.Affinity
    ) throws(Kernel.Thread.Affinity.Error) {
        switch affinity.kind {
        case .any:
            return

        case .cores(let cores):
            try pin(to: cores)

        case .numaNode(let node):
            try pin(to: cpus(of: node))
        }
    }
}

// MARK: - Platform Mechanisms

extension Kernel.Thread.Affinity {
    /// Pins the calling thread to the given logical CPU cores.
    ///
    /// Darwin (macOS/iOS/tvOS/watchOS/visionOS) exposes no thread-affinity
    /// syscall, so the cross-platform surface reports `.unsupported` there.
    private static func pin(
        to cores: Set<Int>
    ) throws(Kernel.Thread.Affinity.Error) {
        #if os(Linux)
            do throws(Linux.Kernel.Thread.Affinity.Error) {
                try Linux.Kernel.Thread.Affinity.setMask(cores: cores)
            } catch {
                switch error {
                case .platform(let code):
                    throw .platform(code)
                }
            }

        #elseif os(Windows)
            do throws(Windows.`32`.Kernel.Thread.Affinity.Error) {
                try Windows.`32`.Kernel.Thread.Affinity.setMask(cores: cores)
            } catch {
                switch error {
                case .unsupported:
                    throw .unsupported

                case .invalidNode(let node):
                    throw .invalidNode(node)

                case .tooManyCPUs:
                    throw .tooManyCPUs

                case .platform(let code):
                    throw .platform(code)
                }
            }

        #else
            throw .unsupported
        #endif
    }

    /// Resolves a NUMA node identifier to the CPUs that node owns.
    private static func cpus(
        of node: Int
    ) throws(Kernel.Thread.Affinity.Error) -> Set<Int> {
        #if os(Linux) || os(Windows)
            guard case .nonUniform(let nodes) = System.Topology.NUMA.discover(),
                let match = nodes.first(where: { $0.id == node })
            else {
                throw .invalidNode(node)
            }
            return match.cpus

        #else
            throw .unsupported
        #endif
    }
}

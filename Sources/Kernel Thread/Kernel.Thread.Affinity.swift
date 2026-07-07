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

        case .cores, .numaNode:
            #if os(Linux)
                try Linux.Thread.Affinity.apply(affinity)
            #elseif os(Windows)
                // Tier 5-Windows-FOS+Affinity-Combined Phase 5 (2026-05-02):
                // restored the Windows-side dispatch removed in Wave 1.9
                // (commit `afb3a19`). The Path X relocation orphan that blocked
                // Wave 1.9 is now resolved: Phase 1 recreated the L2 type at
                // `Windows.\`32\`.Kernel.Thread.Affinity` (swift-windows-32
                // commit `7509c37`), Phase 3 added the L3-policy
                // `Windows.Kernel.Thread.Affinity.apply(_:)` dispatch surface
                // at swift-windows (commit `f40a2e9`), and Phase 5 re-exports
                // the `Windows Kernel Thread` product through Kernel Thread's
                // exports so this call site can resolve.
                try Windows.Kernel.Thread.Affinity.apply(affinity)
            #else
                // Darwin: macOS/iOS/tvOS/watchOS/visionOS lack thread affinity
                // syscalls; the cross-platform surface throws `.unsupported`
                // for non-`.any` cases on these platforms.
                throw .unsupported
            #endif
        }
    }
}

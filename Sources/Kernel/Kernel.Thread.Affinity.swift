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

public import Kernel_Primitives

#if canImport(Darwin_Kernel)
import Darwin_Kernel
#elseif canImport(Linux_Kernel)
import Linux_Kernel
#elseif canImport(Windows_Kernel)
import Windows_Kernel
#endif

extension Kernel.Thread {
    /// Unified accessor for thread affinity operations.
    ///
    /// Provides a platform-independent interface for:
    /// - Querying affinity support level
    /// - Applying affinity to the current thread
    ///
    /// ## Usage
    /// ```swift
    /// // Check support level
    /// switch Kernel.Thread.affinity.support {
    /// case .none:
    ///     print("Affinity not supported")
    /// case .advisory:
    ///     print("Affinity is best-effort")
    /// case .enforced:
    ///     print("Affinity will be honored")
    /// }
    ///
    /// // Apply affinity to current thread
    /// try Kernel.Thread.affinity.apply(.cores([0, 1, 2, 3]))
    /// ```
    public static var affinity: AffinityAccessor { AffinityAccessor() }
}

extension Kernel.Thread {
    /// Accessor for thread affinity operations.
    public struct AffinityAccessor: Sendable {
        /// Platform support level for thread affinity.
        ///
        /// - Linux: `.enforced` - pthread_setaffinity_np pins threads
        /// - Windows: `.enforced` - SetThreadAffinityMask pins threads
        /// - Darwin: `.none` - macOS/iOS don't support thread affinity
        public var support: Affinity.Support {
            #if os(Linux)
            return .enforced
            #elseif os(Windows)
            return .enforced
            #else
            return .none
            #endif
        }

        /// Applies affinity to the current thread.
        ///
        /// ## Platform Behavior
        /// - Linux: Uses pthread_setaffinity_np
        /// - Windows: Uses SetThreadAffinityMask
        /// - Darwin: Throws `.unsupported` for non-.any affinity
        ///
        /// - Parameter affinity: The affinity specification.
        /// - Throws: `Kernel.Thread.Affinity.Error` on failure.
        public func apply(_ affinity: Affinity) throws(Affinity.Error) {
            switch affinity.kind {
            case .any:
                // No constraint - always succeeds
                return

            case .cores, .numaNode:
                #if os(Linux)
                try Linux.Thread.Affinity.apply(affinity)
                #elseif os(Windows)
                try Windows.Thread.Affinity.apply(affinity)
                #else
                throw .unsupported
                #endif
            }
        }
    }
}

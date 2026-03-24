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
            try Windows.Thread.Affinity.apply(affinity)
            #else
            throw .unsupported
            #endif
        }
    }
}

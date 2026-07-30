// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel.Thread.Affinity {
    /// Platform support level for thread affinity.
    ///
    /// This is a 3-state capability indicator, not a boolean.
    /// Use this to inform placement decisions.
    ///
    /// ## Usage
    /// ```swift
    /// switch Kernel.Thread.Affinity.support {
    /// case .none:
    ///     print("Affinity not supported on this platform")
    /// case .advisory:
    ///     print("Affinity is best-effort hint")
    /// case .enforced:
    ///     print("Affinity will be honored")
    /// }
    /// ```
    public enum Support: Sendable, Equatable {
        /// Platform does not support thread affinity.
        ///
        /// Attempting to set affinity will fail or be ignored.
        /// Example: macOS, iOS.
        case none

        /// Affinity is advisory only.
        ///
        /// The OS may honor the request but is not required to.
        /// The thread may migrate to other CPUs under load.
        case advisory

        /// Affinity is enforced.
        ///
        /// The thread will be pinned to the specified CPUs.
        /// Example: Linux with pthread_setaffinity_np, Windows with SetThreadAffinityMask.
        case enforced
    }
}

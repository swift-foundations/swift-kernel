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
    /// Failure handling policy for affinity operations.
    ///
    /// Configures how affinity application failures are handled.
    public enum Failure: Sendable, Equatable {
        /// Silently ignore affinity failures.
        ///
        /// Thread continues without affinity constraint.
        case ignore

        /// Report failures via metrics counter.
        ///
        /// Thread continues without affinity constraint,
        /// but failures are observable via metrics.
        case report

        /// Fatal error on certain failures.
        ///
        /// For invalid arguments (programming errors), triggers preconditionFailure.
        /// For transient failures, falls back to `.report` behavior.
        case fatal
    }
}

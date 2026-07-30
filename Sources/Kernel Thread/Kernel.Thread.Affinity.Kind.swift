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
    /// The kind of affinity constraint.
    public enum Kind: Sendable, Equatable {
        /// No constraint - OS scheduler decides CPU placement.
        ///
        /// This is the default behavior for threads.
        case any

        /// Pin to specific logical CPU cores.
        ///
        /// The set contains 0-based logical CPU IDs.
        /// On Linux, this maps to a cpu_set_t.
        /// On Windows, this maps to a GROUP_AFFINITY mask.
        case cores(Set<Int>)

        /// Pin to a NUMA node's CPUs.
        ///
        /// The node ID is resolved to specific CPUs via `System.topology()`
        /// at the point of application. This allows NUMA-aware pinning
        /// without hard-coding CPU IDs.
        ///
        /// If the node ID is invalid or NUMA is unavailable, application
        /// fails with an appropriate error.
        case numaNode(Int)
    }
}

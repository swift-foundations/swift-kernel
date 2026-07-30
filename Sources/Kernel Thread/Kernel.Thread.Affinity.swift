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

extension Kernel.Thread {
    /// Thread affinity specification.
    ///
    /// Describes which CPUs a thread should be allowed to execute on.
    /// This is a logical model independent of platform-specific APIs
    /// (cpu_set_t on Linux, GROUP_AFFINITY on Windows).
    ///
    /// ## Usage
    /// ```swift
    /// // Allow OS to schedule freely
    /// let any = Kernel.Thread.Affinity.any
    ///
    /// // Pin to specific cores
    /// let pinned = Kernel.Thread.Affinity.cores([0, 1, 2, 3])
    ///
    /// // Pin to a NUMA node (resolved via System.topology())
    /// let numa = Kernel.Thread.Affinity.numaNode(0)
    /// ```
    public struct Affinity: Sendable, Equatable {
        /// The affinity specification.
        public let kind: Kind

        /// Creates an affinity with the specified kind.
        public init(kind: Kind) {
            self.kind = kind
        }
    }
}

extension Kernel.Thread.Affinity {
    /// No affinity constraint - OS scheduler decides placement.
    public static let any = Self(kind: .any)

    /// Pin to specific logical CPU cores.
    ///
    /// - Parameter cores: Set of logical CPU IDs (0-based).
    public static func cores(_ cores: some Swift.Sequence<Int>) -> Self {
        Self(kind: .cores(Set(cores)))
    }

    /// Pin to a NUMA node's CPUs.
    ///
    /// The node ID is resolved to specific CPUs via `System.topology()`
    /// at the point of application.
    ///
    /// - Parameter id: NUMA node identifier.
    public static func numaNode(_ id: Int) -> Self {
        Self(kind: .numaNode(id))
    }
}

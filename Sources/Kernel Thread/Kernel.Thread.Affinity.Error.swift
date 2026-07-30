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

public import Error_Primitives

extension Kernel.Thread.Affinity {
    /// Errors from thread affinity operations.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Thread affinity not supported on this platform.
        ///
        /// Darwin/macOS does not support thread affinity.
        case unsupported

        /// Invalid NUMA node identifier.
        case invalidNode(Int)

        /// CPU set exceeds platform capacity.
        ///
        /// On Windows, a single processor group supports at most 64 CPUs.
        case tooManyCPUs

        /// Platform error from the underlying syscall.
        ///
        /// - POSIX: errno from `pthread_setaffinity_np`
        /// - Windows: GetLastError from `SetThreadAffinityMask`
        case platform(Error_Primitives.Error.Code)
    }
}

extension Kernel.Thread.Affinity.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .unsupported:
            return "thread affinity not supported on this platform"
        case .invalidNode(let id):
            return "invalid NUMA node: \(id)"
        case .tooManyCPUs:
            return "CPU set exceeds platform capacity"
        case .platform(let code):
            return "thread affinity failed: \(code)"
        }
    }
}

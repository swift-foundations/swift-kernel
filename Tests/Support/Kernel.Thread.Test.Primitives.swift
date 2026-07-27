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

import Kernel

// MARK: - LockedBox

/// A Sendable box for thread-safe shared state in tests.
///
/// Use this instead of `nonisolated(unsafe)` to maintain
/// proper concurrency safety in tests.
///
/// ## Example
/// ```swift
/// let results = LockedBox<[Int]>([])
/// // In worker thread:
/// results.withLock { $0.append(42) }
/// // In test thread:
/// let values = results.withLock { $0 }
/// ```
public final class LockedBox<T>: @unchecked Sendable {
    private var value: T
    private let lock: Kernel.Thread.Mutex

    public init(_ initial: T) {
        self.value = initial
        self.lock = .init()
    }

    /// Accesses the value under the lock.
    public func withLock<R>(_ body: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

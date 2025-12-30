// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// File locking types and options.
    public enum Lock {}
}

// MARK: - Lock Errors

extension Kernel.Lock {
    /// Lock operation errors.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Lock contention - another process holds a conflicting lock.
        /// - POSIX: `EAGAIN` on `F_SETLK` (non-blocking)
        /// - Windows: `ERROR_LOCK_VIOLATION`
        ///
        /// This is only thrown when `wait: false`. Use `try?` pattern:
        /// ```swift
        /// if (try? Kernel.Lock.lock(fd, range: .file, exclusive: true, wait: false)) != nil {
        ///     // Lock acquired
        /// }
        /// ```
        case contention

        /// Deadlock detected.
        /// - POSIX: `EDEADLK`
        ///
        /// The kernel detected that acquiring this lock would cause
        /// a deadlock with another process.
        case deadlock

        /// No locks available - system lock table exhausted.
        /// - POSIX: `ENOLCK`
        ///
        /// This is resource exhaustion, not contention.
        case unavailable
    }
}

extension Kernel.Lock.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .contention: return "lock contention"
        case .deadlock: return "deadlock detected"
        case .unavailable: return "no locks available"
        }
    }
}

extension Kernel.Lock {
    /// The range of bytes to lock within a file.
    public enum Range: Sendable, Equatable, Hashable {
        /// Lock the entire file.
        case file

        /// Lock a specific byte range.
        ///
        /// - Parameters:
        ///   - start: The starting byte offset (inclusive).
        ///   - end: The ending byte offset (exclusive). Use `UInt64.max` to lock to EOF.
        ///
        /// This matches Swift's `Range<UInt64>` semantics (half-open interval).
        case bytes(start: UInt64, end: UInt64)

        /// Creates a byte range from a Swift Range.
        ///
        /// - Parameter range: The byte range to lock.
        @inlinable
        public init(_ range: Swift.Range<UInt64>) {
            self = .bytes(start: range.lowerBound, end: range.upperBound)
        }
    }

    /// Lock type (shared vs exclusive).
    public enum Kind: Sendable, Equatable, Hashable {
        /// Shared (read) lock. Multiple processes can hold shared locks.
        case shared

        /// Exclusive (write) lock. Only one process can hold an exclusive lock.
        case exclusive
    }
}

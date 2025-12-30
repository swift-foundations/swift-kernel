//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

extension Kernel {
    /// File locking types and options.
    public enum Lock {}
}

extension Kernel.Lock {
    /// The range of bytes to lock within a file.
    public enum Range: Sendable, Equatable, Hashable {
        /// Lock the entire file.
        case file

        /// Lock a specific byte range.
        ///
        /// - Parameters:
        ///   - start: The starting byte offset.
        ///   - length: The number of bytes to lock. Use 0 to lock from start to EOF.
        case bytes(start: UInt64, length: UInt64)
    }

    /// Lock type (shared vs exclusive).
    public enum Kind: Sendable, Equatable, Hashable {
        /// Shared (read) lock. Multiple processes can hold shared locks.
        case shared

        /// Exclusive (write) lock. Only one process can hold an exclusive lock.
        case exclusive
    }
}

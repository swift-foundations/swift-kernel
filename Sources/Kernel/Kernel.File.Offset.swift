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

extension Kernel.File {
    /// File offset for positional I/O operations.
    ///
    /// A type-safe wrapper for file offsets used in `pread`, `pwrite`,
    /// and similar positional I/O operations.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Read at a specific offset
    /// let bytesRead = try Kernel.IO.Read.pread(fd, into: buffer, at: .zero)
    /// let bytesRead = try Kernel.IO.Read.pread(fd, into: buffer, at: Offset(4096))
    ///
    /// // Arithmetic
    /// let nextOffset = offset + 512
    /// ```
    public struct Offset: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: Int64

        @inlinable
        public init(rawValue: Int64) {
            self.rawValue = rawValue
        }

        /// Creates an offset from an integer value.
        @inlinable
        public init(_ value: Int64) {
            self.rawValue = value
        }

        /// Creates an offset from an integer value.
        @inlinable
        public init(_ value: Int) {
            self.rawValue = Int64(value)
        }

        // MARK: - Common Values

        /// Zero offset (beginning of file).
        public static let zero = Offset(rawValue: 0)

        /// Maximum offset (end of file marker for lock ranges).
        public static let max = Offset(rawValue: Int64.max)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: Offset, rhs: Offset) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        // MARK: - Arithmetic

        /// Adds a byte count to an offset.
        @inlinable
        public static func + (lhs: Offset, rhs: Int64) -> Offset {
            Offset(rawValue: lhs.rawValue + rhs)
        }

        /// Adds a byte count to an offset.
        @inlinable
        public static func + (lhs: Offset, rhs: Int) -> Offset {
            Offset(rawValue: lhs.rawValue + Int64(rhs))
        }

        /// Subtracts a byte count from an offset.
        @inlinable
        public static func - (lhs: Offset, rhs: Int64) -> Offset {
            Offset(rawValue: lhs.rawValue - rhs)
        }

        /// Subtracts a byte count from an offset.
        @inlinable
        public static func - (lhs: Offset, rhs: Int) -> Offset {
            Offset(rawValue: lhs.rawValue - Int64(rhs))
        }

        /// Calculates the distance between two offsets.
        @inlinable
        public static func - (lhs: Offset, rhs: Offset) -> Int64 {
            lhs.rawValue - rhs.rawValue
        }

        /// Adds a byte count to an offset in place.
        @inlinable
        public static func += (lhs: inout Offset, rhs: Int64) {
            lhs = Offset(rawValue: lhs.rawValue + rhs)
        }

        /// Adds a byte count to an offset in place.
        @inlinable
        public static func += (lhs: inout Offset, rhs: Int) {
            lhs = Offset(rawValue: lhs.rawValue + Int64(rhs))
        }

        /// Adds a byte count to an offset.
        @inlinable
        public static func + (lhs: Offset, rhs: Kernel.ByteCount) -> Offset {
            Offset(rawValue: lhs.rawValue + Int64(rhs.rawValue))
        }

        /// Adds a byte count to an offset in place.
        @inlinable
        public static func += (lhs: inout Offset, rhs: Kernel.ByteCount) {
            lhs = lhs + rhs
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.File.Offset: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: Int64) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.Offset: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

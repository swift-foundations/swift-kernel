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

extension Kernel {
    /// Byte count for memory and I/O operations.
    ///
    /// A type-safe wrapper for byte counts used in memory mapping,
    /// buffer sizes, and I/O transfer lengths.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Create from pages
    /// let size = Kernel.ByteCount(pages: 4)
    ///
    /// // Validated construction (rejects negative)
    /// if let size = Kernel.ByteCount(rawValue: bufferSize) {
    ///     // Valid non-negative size
    /// }
    ///
    /// // Unchecked for known-valid values
    /// let size = Kernel.ByteCount(unchecked: 4096)
    /// ```
    public struct ByteCount: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: Int

        /// Creates a byte count, validating that it is non-negative.
        ///
        /// - Parameter rawValue: The byte count. Must be ≥ 0.
        /// - Returns: `nil` if the value is negative.
        @inlinable
        public init?(rawValue: Int) {
            guard rawValue >= 0 else { return nil }
            self.rawValue = rawValue
        }

        /// Creates a byte count without validation.
        ///
        /// - Parameter value: The byte count. Must be ≥ 0.
        /// - Precondition: `value` must be non-negative.
        @inlinable
        public init(unchecked value: Int) {
            self.rawValue = value
        }

        /// Creates a byte count from a number of pages.
        ///
        /// - Parameter pages: Number of pages.
        @inlinable
        public init(pages: Int) {
            self.rawValue = pages * Kernel.System.pageSize
        }

        // MARK: - Common Values

        /// Zero bytes.
        public static let zero = ByteCount(unchecked: 0)

        /// One kilobyte (1024 bytes).
        public static let kilobyte = ByteCount(unchecked: 1024)

        /// One megabyte (1024 * 1024 bytes).
        public static let megabyte = ByteCount(unchecked: 1024 * 1024)

        /// One gigabyte (1024 * 1024 * 1024 bytes).
        public static let gigabyte = ByteCount(unchecked: 1024 * 1024 * 1024)

        /// One system page.
        public static var page: ByteCount {
            ByteCount(unchecked: Kernel.System.pageSize)
        }

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        // MARK: - Arithmetic

        /// Adds two byte counts.
        @inlinable
        public static func + (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
            ByteCount(unchecked: lhs.rawValue + rhs.rawValue)
        }

        /// Subtracts two byte counts.
        @inlinable
        public static func - (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
            ByteCount(unchecked: max(0, lhs.rawValue - rhs.rawValue))
        }

        /// Multiplies a byte count by a scalar.
        @inlinable
        public static func * (lhs: ByteCount, rhs: Int) -> ByteCount {
            ByteCount(unchecked: lhs.rawValue * rhs)
        }

        /// Multiplies a byte count by a scalar.
        @inlinable
        public static func * (lhs: Int, rhs: ByteCount) -> ByteCount {
            ByteCount(unchecked: lhs * rhs.rawValue)
        }

        /// Divides a byte count by a scalar.
        @inlinable
        public static func / (lhs: ByteCount, rhs: Int) -> ByteCount {
            ByteCount(unchecked: lhs.rawValue / rhs)
        }

        /// Adds to a byte count in place.
        @inlinable
        public static func += (lhs: inout ByteCount, rhs: ByteCount) {
            lhs = lhs + rhs
        }

        // MARK: - Queries

        /// Whether this byte count is zero.
        @inlinable
        public var isZero: Bool {
            rawValue == 0
        }

        /// Whether this byte count is positive (greater than zero).
        @inlinable
        public var isPositive: Bool {
            rawValue > 0
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.ByteCount: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: Int) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.ByteCount: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

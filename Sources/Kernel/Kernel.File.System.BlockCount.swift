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

extension Kernel.File.System {
    /// Block count for filesystem statistics.
    ///
    /// A type-safe wrapper for filesystem block counts (total, free, available).
    /// Multiply by the block size to get the size in bytes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats = try Kernel.File.System.Stats.get(path)
    /// let freeBytes = stats.freeBlocks.rawValue * stats.blockSize.rawValue
    /// ```
    public struct BlockCount: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: UInt64

        /// Creates a block count from a raw value.
        @inlinable
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// Creates a block count from a UInt64 value.
        @inlinable
        public init(_ value: UInt64) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// Zero blocks.
        public static let zero = BlockCount(rawValue: 0)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: BlockCount, rhs: BlockCount) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.File.System.BlockCount: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.System.BlockCount: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

// MARK: - Arithmetic

extension Kernel.File.System.BlockCount {
    /// Adds two block counts.
    @inlinable
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(rawValue: lhs.rawValue + rhs.rawValue)
    }

    /// Subtracts two block counts.
    @inlinable
    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(rawValue: lhs.rawValue - rhs.rawValue)
    }
}

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
    /// Filesystem block types.
    public enum Block {}
}

// MARK: - Block.Size

extension Kernel.File.System.Block {
    /// Filesystem block size.
    ///
    /// A type-safe wrapper for the fundamental block size of a filesystem.
    /// All I/O operations are ultimately performed in multiples of this size.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats = try Kernel.File.System.Stats.get(path)
    /// let totalBytes = stats.blocks.rawValue * stats.blockSize.rawValue
    /// ```
    public struct Size: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: UInt64

        /// Creates a block size from a raw value.
        @inlinable
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// Creates a block size from a UInt64 value.
        @inlinable
        public init(_ value: UInt64) {
            self.rawValue = value
        }

        // MARK: - Common Block Sizes

        /// 512-byte sector (traditional disk sector).
        public static let sector512 = Size(rawValue: 512)

        /// 4096-byte page (common filesystem block size).
        public static let page4096 = Size(rawValue: 4096)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Block.Size + ExpressibleByIntegerLiteral

extension Kernel.File.System.Block.Size: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}

// MARK: - Block.Size + CustomStringConvertible

extension Kernel.File.System.Block.Size: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

// MARK: - Block.Count

extension Kernel.File.System.Block {
    /// Block count for filesystem statistics.
    ///
    /// A type-safe wrapper for filesystem block counts (total, free, available).
    /// Multiply by the block size to get the size in bytes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats = try Kernel.File.System.Stats.get(path)
    /// let freeBytes = stats.freeBlocks._rawValue * stats.blockSize.rawValue
    /// ```
    public typealias Count = Tagged<Kernel.File.System.Block, UInt64>
}

// MARK: - Block.Count Constants & Arithmetic

extension Tagged where Tag == Kernel.File.System.Block, RawValue == UInt64 {
    /// Zero blocks.
    public static var zero: Self { Self(0) }

    /// Adds two block counts.
    @inlinable
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(lhs._rawValue + rhs._rawValue)
    }

    /// Subtracts two block counts.
    @inlinable
    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(lhs._rawValue - rhs._rawValue)
    }
}

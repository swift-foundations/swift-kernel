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
    public struct BlockSize: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
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
        public static let sector512 = BlockSize(rawValue: 512)

        /// 4096-byte page (common filesystem block size).
        public static let page4096 = BlockSize(rawValue: 4096)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: BlockSize, rhs: BlockSize) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.File.System.BlockSize: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.System.BlockSize: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

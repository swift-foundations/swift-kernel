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
    /// Hard link count for a file.
    ///
    /// A type-safe wrapper for the number of hard links to a file.
    /// Regular files start with a link count of 1. Directories typically
    /// have 2 + (number of subdirectories) links.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats = try Kernel.File.Stats.get(path)
    /// if stats.linkCount > .one {
    ///     // File has multiple hard links
    /// }
    /// ```
    public struct LinkCount: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: UInt32

        /// Creates a link count from a raw value.
        @inlinable
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Creates a link count from a UInt32 value.
        @inlinable
        public init(_ value: UInt32) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// A single link (typical for newly created files).
        public static let one = LinkCount(1)

        /// Zero links (file is being deleted).
        public static let zero = LinkCount(0)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: LinkCount, rhs: LinkCount) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.LinkCount: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.LinkCount: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

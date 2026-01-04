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
    /// Link-related types.
    public enum Link {}
}

// MARK: - Link.Count

extension Kernel.Link {
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
    public struct Count: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
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
        public static let one = Count(1)

        /// Zero links (file is being deleted).
        public static let zero = Count(0)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Link.Count + ExpressibleByIntegerLiteral

extension Kernel.Link.Count: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - Link.Count + CustomStringConvertible

extension Kernel.Link.Count: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

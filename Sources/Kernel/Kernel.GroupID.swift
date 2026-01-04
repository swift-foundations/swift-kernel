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
    /// POSIX group ID.
    ///
    /// A type-safe wrapper for group identifiers used in file ownership
    /// and permission checks.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats = try Kernel.File.Stats.get(path)
    /// if stats.gid == .root {
    ///     // File is owned by root group
    /// }
    /// ```
    public struct GroupID: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: UInt32

        /// Creates a group ID from a raw value.
        @inlinable
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Creates a group ID from a UInt32 value.
        @inlinable
        public init(_ value: UInt32) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// The root group (gid 0).
        public static let root = GroupID(0)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: GroupID, rhs: GroupID) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.GroupID: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.GroupID: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

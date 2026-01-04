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
    /// User-related types.
    public enum User {}
}

// MARK: - User.ID

extension Kernel.User {
    /// POSIX user ID.
    ///
    /// A type-safe wrapper for user identifiers used in file ownership
    /// and permission checks.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats = try Kernel.File.Stats.get(path)
    /// if stats.uid == .root {
    ///     // File is owned by root
    /// }
    /// ```
    public struct ID: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: UInt32

        /// Creates a user ID from a raw value.
        @inlinable
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Creates a user ID from a UInt32 value.
        @inlinable
        public init(_ value: UInt32) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// The root user (uid 0).
        public static let root = ID(0)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - User.ID + ExpressibleByIntegerLiteral

extension Kernel.User.ID: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - User.ID + CustomStringConvertible

extension Kernel.User.ID: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

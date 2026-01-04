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
    public struct UserID: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
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
        public static let root = UserID(0)

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: UserID, rhs: UserID) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.UserID: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.UserID: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

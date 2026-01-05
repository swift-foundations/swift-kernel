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
    /// Generic tagged identifier.
    ///
    /// Type-safe ID wrapper that prevents mixing IDs from different domains.
    /// The phantom `Tag` type provides compile-time safety without runtime cost.
    ///
    /// ## Usage
    /// ```swift
    /// enum JobTag {}
    /// typealias JobID = Kernel.ID<JobTag>
    ///
    /// let id = JobID(rawValue: 42)
    /// ```
    ///
    /// ## Design
    /// - `rawValue` is `UInt64` for efficient storage and atomic operations
    /// - Phantom `Tag` type prevents accidental mixing of IDs from different domains
    /// - Conforms to `Hashable` for use in collections
    /// - Conforms to `Sendable` for thread-safe usage
    public struct ID<Tag>: Hashable, Sendable {
        /// The underlying raw value.
        public let rawValue: UInt64

        /// Creates an ID with the given raw value.
        @inlinable
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.ID: CustomStringConvertible {
    public var description: String {
        "ID(\(rawValue))"
    }
}

// MARK: - Comparable

extension Kernel.ID: Comparable {
    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.ID: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}

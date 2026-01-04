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

#if canImport(Glibc) || canImport(Musl)

extension Kernel.IOUring {
    /// Personality identifier for credential switching.
    ///
    /// Used to execute I/O operations with different credentials than the
    /// process's default. Personalities are registered with `IORING_REGISTER_PERSONALITY`
    /// and referenced in SQEs.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Register a personality (returns ID)
    /// let personality = PersonalityID(registerResult)
    ///
    /// // Use in SQE to run with those credentials
    /// sqe.personality = personality
    /// ```
    public struct PersonalityID: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt16

        /// Creates a personality ID from a raw value.
        @inlinable
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        /// Creates a personality ID from a UInt16 value.
        @inlinable
        public init(_ value: UInt16) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// No personality (use process credentials).
        public static let none = PersonalityID(0)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.IOUring.PersonalityID: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.IOUring.PersonalityID: CustomStringConvertible {
    public var description: String {
        if self == .none {
            return "none"
        }
        return "\(rawValue)"
    }
}

#endif

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if canImport(Darwin)
public import Darwin

extension Kernel.Kqueue {
    /// Filter-specific flags (fflags field).
    ///
    /// Used with EVFILT_USER for triggering user events.
    public struct FilterFlags: Sendable, Equatable, Hashable {
        public let rawValue: UInt32

        @inlinable
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Kqueue.FilterFlags {
    /// Trigger the user event immediately.
    public static let trigger = Self(rawValue: UInt32(NOTE_TRIGGER))

    /// No filter flags.
    public static let none = Self(rawValue: 0)

    /// Combines multiple filter flags.
    @inlinable
    public static func | (lhs: Self, rhs: Self) -> Self {
        Self(rawValue: lhs.rawValue | rhs.rawValue)
    }

    /// Checks if this contains another filter flag.
    @inlinable
    public func contains(_ other: Self) -> Bool {
        (rawValue & other.rawValue) == other.rawValue
    }
}

#endif

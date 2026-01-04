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
public import Kernel_Primitives

#if canImport(Darwin)
    public import Darwin

    extension Kernel.Kqueue {
        /// Action and status flags for kqueue events.
        ///
        /// These flags control the behavior of event registration and
        /// report status in returned events.
        public struct Flags: Sendable, Equatable, Hashable {
            public let rawValue: UInt16

            @inlinable
            public init(rawValue: UInt16) {
                self.rawValue = rawValue
            }
        }
    }

    // MARK: - Action Flags

    extension Kernel.Kqueue.Flags {
        /// Add event to kqueue (enables if already added).
        public static let add = Self(rawValue: UInt16(EV_ADD))

        /// Delete event from kqueue.
        public static let delete = Self(rawValue: UInt16(EV_DELETE))

        /// Enable event delivery.
        public static let enable = Self(rawValue: UInt16(EV_ENABLE))

        /// Disable event delivery (event remains in kqueue).
        public static let disable = Self(rawValue: UInt16(EV_DISABLE))
    }

    // MARK: - Behavior Flags

    extension Kernel.Kqueue.Flags {
        /// Clear state after retrieval (edge-triggered).
        public static let clear = Self(rawValue: UInt16(EV_CLEAR))

        /// Disable after delivery (one-shot).
        public static let dispatch = Self(rawValue: UInt16(EV_DISPATCH))

        /// Delete event after delivery.
        public static let oneshot = Self(rawValue: UInt16(EV_ONESHOT))
    }

    // MARK: - Status Flags (Output Only)

    extension Kernel.Kqueue.Flags {
        /// EOF condition on descriptor.
        public static let eof = Self(rawValue: UInt16(EV_EOF))

        /// Error condition on descriptor.
        public static let error = Self(rawValue: UInt16(EV_ERROR))
    }

    // MARK: - Combining

    extension Kernel.Kqueue.Flags {
        /// Combines multiple flags.
        @inlinable
        public static func | (lhs: Self, rhs: Self) -> Self {
            Self(rawValue: lhs.rawValue | rhs.rawValue)
        }

        /// Checks if this contains another flag.
        @inlinable
        public func contains(_ other: Self) -> Bool {
            (rawValue & other.rawValue) == other.rawValue
        }

        /// Returns an empty set of flags.
        public static let none = Self(rawValue: 0)
    }

#endif

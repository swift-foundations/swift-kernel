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

#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Event.Poll {
        /// Event flags for epoll.
        public struct Events: Sendable, Equatable, Hashable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }
        }
    }

    // MARK: - Event Flags

    extension Kernel.Event.Poll.Events {
        /// The associated file is available for read operations.
        public static let `in` = Self(rawValue: EPOLLIN.rawValue)

        /// The associated file is available for write operations.
        public static let out = Self(rawValue: EPOLLOUT.rawValue)

        /// Stream socket peer closed connection, or shut down writing half.
        public static let rdhup = Self(rawValue: EPOLLRDHUP.rawValue)

        /// Urgent data available for read.
        public static let pri = Self(rawValue: EPOLLPRI.rawValue)

        /// Error condition happened.
        public static let err = Self(rawValue: EPOLLERR.rawValue)

        /// Hang up happened.
        public static let hup = Self(rawValue: EPOLLHUP.rawValue)

        /// Edge-triggered behavior.
        public static let et = Self(rawValue: EPOLLET.rawValue)

        /// One-shot behavior: disable after one event delivery.
        public static let oneshot = Self(rawValue: EPOLLONESHOT.rawValue)
    }

    // MARK: - Combining

    extension Kernel.Event.Poll.Events {
        /// Combines multiple event flags.
        @inlinable
        public static func | (lhs: Self, rhs: Self) -> Self {
            Self(rawValue: lhs.rawValue | rhs.rawValue)
        }

        /// Checks if this contains another event flag.
        @inlinable
        public func contains(_ other: Self) -> Bool {
            (rawValue & other.rawValue) == other.rawValue
        }
    }

#endif

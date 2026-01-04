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

extension Kernel.Event {
    /// Unified event routing data for epoll, kqueue, and io_uring.
    ///
    /// User data is an opaque value associated with event registrations that
    /// is returned when the event fires. This enables efficient event routing
    /// without additional lookups.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // From an identifier
    /// let userData = Event.UserData(42)
    ///
    /// // From a pointer (for object association)
    /// let userData = Event.UserData(pointer: contextPtr)
    /// ```
    ///
    /// ## Platform Notes
    ///
    /// - **epoll**: Maps to `epoll_data_t.u64`
    /// - **kqueue**: Maps to `udata` field (pointer on 64-bit)
    /// - **io_uring**: Maps to `user_data` field in submission/completion queue entries
    public struct UserData: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt64

        /// Creates user data from a raw 64-bit value.
        @inlinable
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// Creates user data from a UInt64 value.
        @inlinable
        public init(_ value: UInt64) {
            self.rawValue = value
        }

        /// Creates user data from a pointer.
        ///
        /// Useful for associating an object context with an event.
        @inlinable
        public init(_ pointer: UnsafeRawPointer) {
            self.rawValue = UInt64(UInt(bitPattern: pointer))
        }

        /// Creates user data from a typed pointer.
        @inlinable
        public init<T>(pointer: UnsafePointer<T>) {
            self.rawValue = UInt64(UInt(bitPattern: pointer))
        }

        /// Creates user data from a mutable typed pointer.
        @inlinable
        public init<T>(pointer: UnsafeMutablePointer<T>) {
            self.rawValue = UInt64(UInt(bitPattern: pointer))
        }

        // MARK: - Common Values

        /// Zero user data.
        public static let zero = UserData(rawValue: 0)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.Event.UserData: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Event.UserData: CustomStringConvertible {
    public var description: String {
        "UserData(\(rawValue))"
    }
}

// MARK: - IOUring.UserData Conversion

#if canImport(Glibc) || canImport(Musl)

extension Kernel.Event.UserData {
    /// Creates Event.UserData from IOUring.UserData.
    @inlinable
    public init(_ userData: Kernel.IOUring.UserData) {
        self.init(rawValue: userData.rawValue)
    }
}

extension Kernel.IOUring.UserData {
    /// Creates IOUring.UserData from Event.UserData.
    @inlinable
    public init(_ eventUserData: Kernel.Event.UserData) {
        self.init(rawValue: eventUserData.rawValue)
    }
}

#endif

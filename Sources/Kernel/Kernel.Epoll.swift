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

#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        internal import Musl
    #endif

    extension Kernel {
        /// Raw epoll syscall wrappers (Linux only).
        ///
        /// Epoll is the scalable I/O event notification mechanism on Linux.
        /// This namespace provides policy-free syscall wrappers.
        ///
        /// Higher layers (swift-io) build registration management,
        /// ID tracking, and event dispatch on top of these primitives.
        public enum Epoll {}
    }

    // MARK: - Error Type

    extension Kernel.Epoll {
        /// Errors from epoll operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create epoll instance.
            case createFailed(errno: Int32)

            /// Failed to control epoll (add/modify/delete).
            case ctlFailed(errno: Int32)

            /// Failed to wait for events.
            case waitFailed(errno: Int32)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.Epoll.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .createFailed(let errno):
                return "epoll_create1 failed (errno: \(errno))"
            case .ctlFailed(let errno):
                return "epoll_ctl failed (errno: \(errno))"
            case .waitFailed(let errno):
                return "epoll_wait failed (errno: \(errno))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

    // MARK: - Operation Constants

    extension Kernel.Epoll {
        /// Operations for `epoll_ctl`.
        public struct Operation: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: Int32

            @inlinable
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// Add a file descriptor to the epoll instance.
            public static let add = Operation(rawValue: EPOLL_CTL_ADD)

            /// Modify the events for a file descriptor.
            public static let modify = Operation(rawValue: EPOLL_CTL_MOD)

            /// Remove a file descriptor from the epoll instance.
            public static let delete = Operation(rawValue: EPOLL_CTL_DEL)
        }
    }

    // MARK: - Event Flags

    extension Kernel.Epoll {
        /// Event flags for epoll.
        public struct Events: Sendable, Equatable, Hashable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// The associated file is available for read operations.
            public static let `in` = Events(rawValue: UInt32(EPOLLIN))

            /// The associated file is available for write operations.
            public static let out = Events(rawValue: UInt32(EPOLLOUT))

            /// Stream socket peer closed connection, or shut down writing half.
            public static let rdhup = Events(rawValue: UInt32(EPOLLRDHUP))

            /// Urgent data available for read.
            public static let pri = Events(rawValue: UInt32(EPOLLPRI))

            /// Error condition happened.
            public static let err = Events(rawValue: UInt32(EPOLLERR))

            /// Hang up happened.
            public static let hup = Events(rawValue: UInt32(EPOLLHUP))

            /// Edge-triggered behavior.
            public static let et = Events(rawValue: UInt32(EPOLLET))

            /// One-shot behavior: disable after one event delivery.
            public static let oneshot = Events(rawValue: UInt32(EPOLLONESHOT))

            /// Combines multiple event flags.
            @inlinable
            public static func | (lhs: Events, rhs: Events) -> Events {
                Events(rawValue: lhs.rawValue | rhs.rawValue)
            }

            /// Checks if this contains another event flag.
            @inlinable
            public func contains(_ other: Events) -> Bool {
                (rawValue & other.rawValue) == other.rawValue
            }
        }
    }

    // MARK: - Create Flags

    extension Kernel.Epoll {
        /// Flags for `epoll_create1`.
        public struct CreateFlags: Sendable, Equatable, Hashable {
            public let rawValue: Int32

            @inlinable
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }

            /// No flags.
            public static let none = CreateFlags(rawValue: 0)

            /// Set close-on-exec flag on the new file descriptor.
            public static let cloexec = CreateFlags(rawValue: EPOLL_CLOEXEC)

            /// Combines multiple flags.
            @inlinable
            public static func | (lhs: CreateFlags, rhs: CreateFlags) -> CreateFlags {
                CreateFlags(rawValue: lhs.rawValue | rhs.rawValue)
            }
        }
    }

    // MARK: - Syscalls

    extension Kernel.Epoll {
        /// Creates a new epoll instance.
        ///
        /// - Parameter flags: Flags for the new epoll instance.
        /// - Returns: A file descriptor for the new epoll instance.
        /// - Throws: `Error.createFailed` if creation fails.
        @inlinable
        public static func create(flags: CreateFlags = .cloexec) throws(Error) -> Kernel.Descriptor {
            let epfd = epoll_create1(flags.rawValue)
            guard epfd >= 0 else {
                throw .createFailed(errno: errno)
            }
            return epfd
        }

        /// Controls the epoll instance (add/modify/delete).
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - op: The operation to perform.
        ///   - fd: The target file descriptor.
        ///   - event: The event structure (can be nil for delete).
        /// - Throws: `Error.ctlFailed` if the operation fails.
        @inlinable
        public static func ctl(
            _ epfd: Kernel.Descriptor,
            op: Operation,
            fd: Kernel.Descriptor,
            event: UnsafeMutablePointer<epoll_event>?
        ) throws(Error) {
            let result = epoll_ctl(epfd, op.rawValue, fd, event)
            guard result == 0 else {
                throw .ctlFailed(errno: errno)
            }
        }

        /// Waits for events on the epoll instance.
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - events: Buffer for returned events.
        ///   - maxEvents: Maximum number of events to return.
        ///   - timeout: Timeout in milliseconds (-1 for infinite, 0 for immediate).
        /// - Returns: Number of events, or 0 on timeout.
        /// - Throws: `Error.waitFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func wait(
            _ epfd: Kernel.Descriptor,
            events: UnsafeMutablePointer<epoll_event>,
            maxEvents: Int32,
            timeout: Int32
        ) throws(Error) -> Int {
            let result = epoll_wait(epfd, events, maxEvents, timeout)
            guard result >= 0 else {
                let err = errno
                if err == EINTR {
                    throw .interrupted
                }
                throw .waitFailed(errno: err)
            }
            return Int(result)
        }

        /// Waits for events on the epoll instance (buffer pointer variant).
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - events: Buffer for returned events.
        ///   - timeout: Timeout in milliseconds (-1 for infinite, 0 for immediate).
        /// - Returns: Number of events, or 0 on timeout.
        /// - Throws: `Error.waitFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func wait(
            _ epfd: Kernel.Descriptor,
            events: UnsafeMutableBufferPointer<epoll_event>,
            timeout: Int32
        ) throws(Error) -> Int {
            guard let baseAddress = events.baseAddress else {
                return 0
            }
            return try wait(epfd, events: baseAddress, maxEvents: Int32(events.count), timeout: timeout)
        }
    }

    // MARK: - Duration Convenience

    extension Kernel.Epoll {
        /// Waits for events with a Duration timeout.
        ///
        /// Convenience wrapper that converts Duration to milliseconds.
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - events: Buffer for returned events.
        ///   - timeout: Timeout duration, or `nil` for infinite.
        /// - Returns: Number of events, or 0 on timeout.
        /// - Throws: `Error.waitFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func wait(
            _ epfd: Kernel.Descriptor,
            events: UnsafeMutableBufferPointer<epoll_event>,
            timeout: Duration?
        ) throws(Error) -> Int {
            let ms = Kernel.Time.milliseconds(from: timeout)
            return try wait(epfd, events: events, timeout: ms)
        }
    }

#endif

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
            public static let `in` = Events(rawValue: EPOLLIN.rawValue)

            /// The associated file is available for write operations.
            public static let out = Events(rawValue: EPOLLOUT.rawValue)

            /// Stream socket peer closed connection, or shut down writing half.
            public static let rdhup = Events(rawValue: EPOLLRDHUP.rawValue)

            /// Urgent data available for read.
            public static let pri = Events(rawValue: EPOLLPRI.rawValue)

            /// Error condition happened.
            public static let err = Events(rawValue: EPOLLERR.rawValue)

            /// Hang up happened.
            public static let hup = Events(rawValue: EPOLLHUP.rawValue)

            /// Edge-triggered behavior.
            public static let et = Events(rawValue: EPOLLET.rawValue)

            /// One-shot behavior: disable after one event delivery.
            public static let oneshot = Events(rawValue: EPOLLONESHOT.rawValue)

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

    // MARK: - Event Type

    extension Kernel.Epoll {
        /// Swift wrapper for epoll_event C struct.
        ///
        /// Provides a Sendable, Swift-native interface to epoll events.
        public struct Event: Sendable, Equatable, Hashable {
            /// The event flags that occurred or are being monitored.
            public var events: Events

            /// User data associated with the file descriptor.
            ///
            /// This is typically used to store an identifier that helps dispatch
            /// the event to the appropriate handler.
            public var data: UInt64

            /// Creates an epoll event.
            ///
            /// - Parameters:
            ///   - events: The event flags to monitor.
            ///   - data: User data to associate with the file descriptor.
            @inlinable
            public init(events: Events, data: UInt64 = 0) {
                self.events = events
                self.data = data
            }

            /// Creates an epoll event from the C struct.
            @usableFromInline
            internal init(_ cEvent: epoll_event) {
                self.events = Events(rawValue: cEvent.events)
                self.data = cEvent.data.u64
            }

            /// Converts to the C epoll_event struct.
            @usableFromInline
            internal var cValue: epoll_event {
                var event = epoll_event()
                event.events = events.rawValue
                event.data.u64 = data
                return event
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
            public static let cloexec = CreateFlags(rawValue: Int32(EPOLL_CLOEXEC))

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
            return Kernel.Descriptor(rawValue: epfd)
        }

        /// Controls the epoll instance (add/modify/delete).
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - op: The operation to perform.
        ///   - fd: The target file descriptor.
        ///   - event: The event structure (required for add/modify, ignored for delete).
        /// - Throws: `Error.ctlFailed` if the operation fails.
        @inlinable
        public static func ctl(
            _ epfd: Kernel.Descriptor,
            op: Operation,
            fd: Kernel.Descriptor,
            event: Event? = nil
        ) throws(Error) {
            let result: Int32
            if var cEvent = event?.cValue {
                result = epoll_ctl(epfd.rawValue, op.rawValue, fd.rawValue, &cEvent)
            } else {
                result = epoll_ctl(epfd.rawValue, op.rawValue, fd.rawValue, nil)
            }
            guard result == 0 else {
                throw .ctlFailed(errno: errno)
            }
        }

        /// Waits for events on the epoll instance.
        ///
        /// Low-level wait that writes events into a pre-allocated buffer.
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - events: Buffer for returned events.
        ///   - timeout: Timeout in milliseconds (-1 for infinite, 0 for immediate).
        /// - Returns: Number of events written to buffer, or 0 on timeout.
        /// - Throws: `Error.waitFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func wait(
            _ epfd: Kernel.Descriptor,
            events: inout [Event],
            timeout: Int32
        ) throws(Error) -> Int {
            guard !events.isEmpty else { return 0 }

            // Use stack allocation for small buffers, heap for large ones
            let count = events.count
            return try withUnsafeTemporaryAllocation(of: epoll_event.self, capacity: count) { buffer -> Int in
                let result = epoll_wait(epfd.rawValue, buffer.baseAddress!, Int32(count), timeout)
                guard result >= 0 else {
                    let err = errno
                    if err == EINTR {
                        throw Error.interrupted
                    }
                    throw Error.waitFailed(errno: err)
                }

                // Convert C events to Swift events
                for i in 0..<Int(result) {
                    events[i] = Event(buffer[i])
                }
                return Int(result)
            }
        }

        /// Waits for events with a Duration timeout.
        ///
        /// Convenience wrapper that converts Duration to milliseconds.
        ///
        /// - Parameters:
        ///   - epfd: The epoll file descriptor.
        ///   - events: Buffer for returned events.
        ///   - timeout: Timeout duration, or `nil` for infinite.
        /// - Returns: Number of events written to buffer, or 0 on timeout.
        /// - Throws: `Error.waitFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func wait(
            _ epfd: Kernel.Descriptor,
            events: inout [Event],
            timeout: Duration?
        ) throws(Error) -> Int {
            let ms = Kernel.Time.milliseconds(from: timeout)
            return try wait(epfd, events: &events, timeout: ms)
        }
    }

#endif

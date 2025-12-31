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

    extension Kernel {
        /// Raw kqueue syscall wrappers (Darwin only).
        ///
        /// Kqueue is the kernel event notification mechanism on macOS/BSD.
        /// This namespace provides policy-free syscall wrappers.
        ///
        /// Higher layers (swift-io) build registration management,
        /// ID tracking, and event dispatch on top of these primitives.
        public enum Kqueue {}
    }

    // MARK: - Error Type

    extension Kernel.Kqueue {
        /// Errors from kqueue operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create kqueue.
            case createFailed(errno: Int32)

            /// Failed to register/modify events.
            case keventFailed(errno: Int32)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.Kqueue.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .createFailed(let errno):
                return "kqueue creation failed (errno: \(errno))"
            case .keventFailed(let errno):
                return "kevent failed (errno: \(errno))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

    // MARK: - Syscalls

    // Import kevent function explicitly (avoiding conflict with kevent struct)
    @_silgen_name("kevent")
    @usableFromInline
    internal func _kevent(
        _ kq: Int32,
        _ changelist: UnsafePointer<Darwin.kevent>?,
        _ nchanges: Int32,
        _ eventlist: UnsafeMutablePointer<Darwin.kevent>?,
        _ nevents: Int32,
        _ timeout: UnsafePointer<timespec>?
    ) -> Int32

    extension Kernel.Kqueue {
        /// Creates a new kqueue descriptor.
        ///
        /// - Returns: A file descriptor for the new kqueue.
        /// - Throws: `Error.createFailed` if kqueue creation fails.
        @inlinable
        public static func create() throws(Error) -> Kernel.Descriptor {
            let kq = Darwin.kqueue()
            guard kq >= 0 else {
                throw .createFailed(errno: errno)
            }
            return Kernel.Descriptor(rawValue: kq)
        }

        /// Registers events and/or waits for events.
        ///
        /// This is the raw kevent syscall. It can:
        /// - Register new events (changelist)
        /// - Wait for events (eventlist)
        /// - Both simultaneously
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - changelist: Events to register/modify, or `nil`.
        ///   - nchanges: Number of events in changelist.
        ///   - eventlist: Buffer for returned events, or `nil`.
        ///   - nevents: Size of eventlist buffer.
        ///   - timeout: Timeout for waiting, or `nil` for infinite.
        /// - Returns: Number of events placed in eventlist.
        /// - Throws: `Error.keventFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func kevent(
            _ kq: Kernel.Descriptor,
            changelist: UnsafePointer<Darwin.kevent>?,
            nchanges: Int32,
            eventlist: UnsafeMutablePointer<Darwin.kevent>?,
            nevents: Int32,
            timeout: UnsafePointer<timespec>?
        ) throws(Error) -> Int {
            let result = _kevent(kq.rawValue, changelist, nchanges, eventlist, nevents, timeout)
            guard result >= 0 else {
                let err = errno
                if err == EINTR {
                    throw .interrupted
                }
                throw .keventFailed(errno: err)
            }
            return Int(result)
        }

        /// Registers events and/or waits for events (buffer pointer variant).
        ///
        /// Convenience wrapper that takes buffer pointers instead of raw pointers.
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - changelist: Events to register/modify.
        ///   - eventlist: Buffer for returned events.
        ///   - timeout: Timeout for waiting, or `nil` for infinite.
        /// - Returns: Number of events placed in eventlist.
        /// - Throws: `Error.keventFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func kevent(
            _ kq: Kernel.Descriptor,
            changelist: UnsafeBufferPointer<Darwin.kevent>,
            eventlist: UnsafeMutableBufferPointer<Darwin.kevent>,
            timeout: UnsafePointer<timespec>?
        ) throws(Error) -> Int {
            try kevent(
                kq,
                changelist: changelist.baseAddress,
                nchanges: Int32(changelist.count),
                eventlist: eventlist.baseAddress,
                nevents: Int32(eventlist.count),
                timeout: timeout
            )
        }

        /// Registers events without waiting.
        ///
        /// Convenience wrapper for registration-only operations.
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - changelist: Events to register/modify.
        /// - Throws: `Error.keventFailed` on failure.
        @inlinable
        public static func register(
            _ kq: Kernel.Descriptor,
            changelist: UnsafeBufferPointer<Darwin.kevent>
        ) throws(Error) {
            _ = try kevent(
                kq,
                changelist: changelist.baseAddress,
                nchanges: Int32(changelist.count),
                eventlist: nil,
                nevents: 0,
                timeout: nil
            )
        }

        /// Waits for events without registering.
        ///
        /// Convenience wrapper for poll-only operations.
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - eventlist: Buffer for returned events.
        ///   - timeout: Timeout for waiting, or `nil` for infinite.
        /// - Returns: Number of events placed in eventlist.
        /// - Throws: `Error.keventFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func poll(
            _ kq: Kernel.Descriptor,
            eventlist: UnsafeMutableBufferPointer<Darwin.kevent>,
            timeout: UnsafePointer<timespec>?
        ) throws(Error) -> Int {
            try kevent(
                kq,
                changelist: nil,
                nchanges: 0,
                eventlist: eventlist.baseAddress,
                nevents: Int32(eventlist.count),
                timeout: timeout
            )
        }
    }

    // MARK: - Duration Convenience

    extension Kernel.Kqueue {
        /// Waits for events with a Duration timeout.
        ///
        /// Convenience wrapper that converts Duration to timespec.
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - eventlist: Buffer for returned events.
        ///   - timeout: Timeout duration, or `nil` for infinite.
        /// - Returns: Number of events placed in eventlist.
        /// - Throws: `Error.keventFailed` on failure, `Error.interrupted` on EINTR.
        public static func poll(
            _ kq: Kernel.Descriptor,
            eventlist: UnsafeMutableBufferPointer<Darwin.kevent>,
            timeout: Duration?
        ) throws(Error) -> Int {
            if var ts = Kernel.Time.timespec(from: timeout) {
                return try poll(kq, eventlist: eventlist, timeout: &ts)
            } else {
                let nilTimeout: UnsafePointer<timespec>? = nil
                return try poll(kq, eventlist: eventlist, timeout: nilTimeout)
            }
        }
    }

#endif

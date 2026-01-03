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
            case create(errno: Int32)

            /// Failed to register/modify events.
            case kevent(errno: Int32)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.Kqueue.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .create(let errno):
                return "kqueue creation failed (errno: \(errno))"
            case .kevent(let errno):
                return "kevent failed (errno: \(errno))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

    // MARK: - Filter Type

    extension Kernel.Kqueue {
        /// Filter types for kqueue events.
        ///
        /// Filters determine what kind of condition triggers the event.
        public struct Filter: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: Int16

            @inlinable
            public init(rawValue: Int16) {
                self.rawValue = rawValue
            }

            /// Filter for read readiness on a descriptor.
            public static let read = Filter(rawValue: Int16(EVFILT_READ))

            /// Filter for write readiness on a descriptor.
            public static let write = Filter(rawValue: Int16(EVFILT_WRITE))

            /// User-defined filter for inter-thread wakeup.
            public static let user = Filter(rawValue: Int16(EVFILT_USER))
        }
    }

    // MARK: - Event Flags

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

            // MARK: - Action Flags

            /// Add event to kqueue (enables if already added).
            public static let add = Flags(rawValue: UInt16(EV_ADD))

            /// Delete event from kqueue.
            public static let delete = Flags(rawValue: UInt16(EV_DELETE))

            /// Enable event delivery.
            public static let enable = Flags(rawValue: UInt16(EV_ENABLE))

            /// Disable event delivery (event remains in kqueue).
            public static let disable = Flags(rawValue: UInt16(EV_DISABLE))

            // MARK: - Behavior Flags

            /// Clear state after retrieval (edge-triggered).
            public static let clear = Flags(rawValue: UInt16(EV_CLEAR))

            /// Disable after delivery (one-shot).
            public static let dispatch = Flags(rawValue: UInt16(EV_DISPATCH))

            /// Delete event after delivery.
            public static let oneshot = Flags(rawValue: UInt16(EV_ONESHOT))

            // MARK: - Status Flags (Output Only)

            /// EOF condition on descriptor.
            public static let eof = Flags(rawValue: UInt16(EV_EOF))

            /// Error condition on descriptor.
            public static let error = Flags(rawValue: UInt16(EV_ERROR))

            // MARK: - Combining

            /// Combines multiple flags.
            @inlinable
            public static func | (lhs: Flags, rhs: Flags) -> Flags {
                Flags(rawValue: lhs.rawValue | rhs.rawValue)
            }

            /// Checks if this contains another flag.
            @inlinable
            public func contains(_ other: Flags) -> Bool {
                (rawValue & other.rawValue) == other.rawValue
            }

            /// Returns an empty set of flags.
            public static let none = Flags(rawValue: 0)
        }
    }

    // MARK: - Filter-Specific Flags

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

            /// Trigger the user event immediately.
            public static let trigger = FilterFlags(rawValue: UInt32(NOTE_TRIGGER))

            /// No filter flags.
            public static let none = FilterFlags(rawValue: 0)

            /// Combines multiple filter flags.
            @inlinable
            public static func | (lhs: FilterFlags, rhs: FilterFlags) -> FilterFlags {
                FilterFlags(rawValue: lhs.rawValue | rhs.rawValue)
            }

            /// Checks if this contains another filter flag.
            @inlinable
            public func contains(_ other: FilterFlags) -> Bool {
                (rawValue & other.rawValue) == other.rawValue
            }
        }
    }

    // MARK: - Event Type

    extension Kernel.Kqueue {
        /// Swift wrapper for the kevent structure.
        ///
        /// Provides a Sendable, Swift-native interface to kqueue events.
        public struct Event: Sendable, Equatable, Hashable {
            /// Identifier for this event (typically a file descriptor).
            public var ident: UInt

            /// Filter type (read, write, user, etc.).
            public var filter: Filter

            /// Action and status flags.
            public var flags: Flags

            /// Filter-specific flags.
            public var fflags: FilterFlags

            /// Filter-specific data (e.g., bytes available for read).
            public var data: Int

            /// User-defined data for event routing.
            ///
            /// Typically stores an ID to dispatch the event to the correct handler.
            public var udata: UInt64

            /// Creates a kqueue event.
            ///
            /// - Parameters:
            ///   - ident: Event identifier (typically a file descriptor).
            ///   - filter: Filter type determining what triggers the event.
            ///   - flags: Action and behavior flags.
            ///   - fflags: Filter-specific flags.
            ///   - data: Filter-specific data.
            ///   - udata: User data for event routing.
            @inlinable
            public init(
                ident: UInt,
                filter: Filter,
                flags: Flags,
                fflags: FilterFlags = .none,
                data: Int = 0,
                udata: UInt64 = 0
            ) {
                self.ident = ident
                self.filter = filter
                self.flags = flags
                self.fflags = fflags
                self.data = data
                self.udata = udata
            }

            /// Creates an Event from the Darwin kevent struct.
            @usableFromInline
            internal init(_ cEvent: Darwin.kevent) {
                self.ident = cEvent.ident
                self.filter = Filter(rawValue: cEvent.filter)
                self.flags = Flags(rawValue: cEvent.flags)
                self.fflags = FilterFlags(rawValue: cEvent.fflags)
                self.data = cEvent.data
                self.udata = UInt64(UInt(bitPattern: cEvent.udata))
            }

            /// Converts to the Darwin kevent struct.
            @usableFromInline
            internal var cValue: Darwin.kevent {
                var ev = Darwin.kevent()
                ev.ident = ident
                ev.filter = filter.rawValue
                ev.flags = flags.rawValue
                ev.fflags = fflags.rawValue
                ev.data = data
                ev.udata = UnsafeMutableRawPointer(bitPattern: UInt(udata))
                return ev
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
        /// - Throws: `Error.create` if kqueue creation fails.
        @inlinable
        public static func create() throws(Error) -> Kernel.Descriptor {
            let kq = Darwin.kqueue()
            guard kq >= 0 else {
                throw .create(errno: errno)
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
        /// - Throws: `Error.kevent` on failure, `Error.interrupted` on EINTR.
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
                throw .kevent(errno: err)
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
        /// - Throws: `Error.kevent` on failure, `Error.interrupted` on EINTR.
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
        /// - Throws: `Error.kevent` on failure.
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
        /// - Throws: `Error.kevent` on failure, `Error.interrupted` on EINTR.
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
        /// - Throws: `Error.kevent` on failure, `Error.interrupted` on EINTR.
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

    // MARK: - Swift-Native Event API

    extension Kernel.Kqueue {
        /// Registers events without waiting (Swift-native interface).
        ///
        /// Takes Swift `Event` structs instead of raw `Darwin.kevent`.
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - events: Array of events to register/modify.
        /// - Throws: `Error.kevent` on failure.
        @inlinable
        public static func register(
            _ kq: Kernel.Descriptor,
            events: [Event]
        ) throws(Error) {
            guard !events.isEmpty else { return }

            // Convert Swift events to C events using stack allocation
            var registerError: Error? = nil
            withUnsafeTemporaryAllocation(
                of: Darwin.kevent.self,
                capacity: events.count
            ) { buffer in
                for i in 0..<events.count {
                    buffer[i] = events[i].cValue
                }
                do {
                    _ = try kevent(
                        kq,
                        changelist: buffer.baseAddress,
                        nchanges: Int32(events.count),
                        eventlist: nil,
                        nevents: 0,
                        timeout: nil
                    )
                } catch let error as Error {
                    registerError = error
                } catch {
                    // Should never reach here with typed throws
                }
            }
            if let error = registerError {
                throw error
            }
        }

        /// Waits for events (Swift-native interface).
        ///
        /// Takes a Swift `[Event]` buffer instead of raw `Darwin.kevent`.
        ///
        /// - Parameters:
        ///   - kq: The kqueue descriptor.
        ///   - events: Buffer for returned events (pre-sized).
        ///   - timeout: Timeout duration, or `nil` for infinite.
        /// - Returns: Number of events written to buffer.
        /// - Throws: `Error.kevent` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func poll(
            _ kq: Kernel.Descriptor,
            into events: inout [Event],
            timeout: Duration?
        ) throws(Error) -> Int {
            guard !events.isEmpty else { return 0 }

            let count = events.count
            var pollError: Error? = nil
            var eventCount = 0

            withUnsafeTemporaryAllocation(
                of: Darwin.kevent.self,
                capacity: count
            ) { buffer in
                do {
                    if var ts = Kernel.Time.timespec(from: timeout) {
                        eventCount = try kevent(
                            kq,
                            changelist: nil,
                            nchanges: 0,
                            eventlist: buffer.baseAddress,
                            nevents: Int32(count),
                            timeout: &ts
                        )
                    } else {
                        let nilTimeout: UnsafePointer<timespec>? = nil
                        eventCount = try kevent(
                            kq,
                            changelist: nil,
                            nchanges: 0,
                            eventlist: buffer.baseAddress,
                            nevents: Int32(count),
                            timeout: nilTimeout
                        )
                    }

                    // Convert C events to Swift events
                    for i in 0..<eventCount {
                        events[i] = Event(buffer[i])
                    }
                } catch let error as Error {
                    pollError = error
                } catch {
                    // Should never reach here with typed throws
                }
            }

            if let error = pollError {
                throw error
            }
            return eventCount
        }
    }

#endif

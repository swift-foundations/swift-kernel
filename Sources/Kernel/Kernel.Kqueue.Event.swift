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
    }
}

// MARK: - Darwin Conversion

extension Kernel.Kqueue.Event {
    /// Creates an Event from the Darwin kevent struct.
    @usableFromInline
    internal init(_ cEvent: Darwin.kevent) {
        self.ident = cEvent.ident
        self.filter = Kernel.Kqueue.Filter(rawValue: cEvent.filter)
        self.flags = Kernel.Kqueue.Flags(rawValue: cEvent.flags)
        self.fflags = Kernel.Kqueue.FilterFlags(rawValue: cEvent.fflags)
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

#endif

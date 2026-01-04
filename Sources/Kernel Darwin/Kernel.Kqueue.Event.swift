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
        /// Swift wrapper for the kevent structure.
        ///
        /// Provides a Sendable, Swift-native interface to kqueue events.
        public struct Event: Sendable, Equatable, Hashable {
            /// Identifier for this event.
            ///
            /// The meaning depends on the filter type:
            /// - `EVFILT_READ`, `EVFILT_WRITE`: file descriptor
            /// - `EVFILT_SIGNAL`: signal number
            /// - `EVFILT_PROC`: process ID
            public var id: Kernel.Event.ID

            /// Filter type (EVFILT_READ, EVFILT_WRITE, etc.).
            public var filter: Filter

            /// Action and status flags (EV_ADD, EV_DELETE, etc.).
            public var flags: Flags

            /// Filter-specific flags.
            public var fflags: Filter.Flags

            /// Filter-specific data (e.g., bytes available for read).
            public var filterData: Filter.Data

            /// User-defined data for event routing.
            ///
            /// Typically stores an ID to dispatch the event to the correct handler.
            public var data: Data

            /// Creates a kqueue event.
            ///
            /// - Parameters:
            ///   - id: Event source identifier.
            ///   - filter: Filter type.
            ///   - flags: Action and behavior flags.
            ///   - fflags: Filter-specific flags.
            ///   - filterData: Filter-specific data.
            ///   - data: User-defined routing data.
            @inlinable
            public init(
                id: Kernel.Event.ID,
                filter: Filter,
                flags: Flags,
                fflags: Filter.Flags = .none,
                filterData: Filter.Data = .zero,
                data: Data = .zero
            ) {
                self.id = id
                self.filter = filter
                self.flags = flags
                self.fflags = fflags
                self.filterData = filterData
                self.data = data
            }
        }
    }

    // MARK: - Darwin Conversion

    extension Kernel.Kqueue.Event {
        /// Creates an Event from the Darwin kevent struct.
        @usableFromInline
        internal init(_ cEvent: Darwin.kevent) {
            self.id = Kernel.Event.ID(cEvent.ident)
            self.filter = Kernel.Kqueue.Filter(rawValue: cEvent.filter)
            self.flags = Kernel.Kqueue.Flags(rawValue: cEvent.flags)
            self.fflags = Kernel.Kqueue.Filter.Flags(rawValue: cEvent.fflags)
            self.filterData = Kernel.Kqueue.Filter.Data(cEvent.data)
            self.data = Data(cEvent.udata)
        }

        /// Converts to the Darwin kevent struct.
        @usableFromInline
        internal var cValue: Darwin.kevent {
            var ev = Darwin.kevent()
            ev.ident = id._rawValue
            ev.filter = filter.rawValue
            ev.flags = flags.rawValue
            ev.fflags = fflags.rawValue
            ev.data = filterData._rawValue
            ev.udata = UnsafeMutableRawPointer(data)
            return ev
        }
    }

#endif

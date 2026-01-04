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

            /// Filter configuration for this event.
            public var filter: FilterConfiguration

            /// Action and status flags.
            public var flags: Flags

            /// Event data for event routing.
            ///
            /// Typically stores an ID to dispatch the event to the correct handler.
            public var data: Data

            /// Creates a kqueue event.
            ///
            /// - Parameters:
            ///   - id: Event source identifier.
            ///   - filter: Filter configuration for this event.
            ///   - flags: Action and behavior flags.
            ///   - data: Event data for event routing.
            @inlinable
            public init(
                id: Kernel.Event.ID,
                filter: FilterConfiguration,
                flags: Flags,
                data: Data = .zero
            ) {
                self.id = id
                self.filter = filter
                self.flags = flags
                self.data = data
            }
        }
    }

    // MARK: - Filter Configuration

    extension Kernel.Kqueue.Event {
        /// Filter configuration containing type, flags, and data.
        public struct FilterConfiguration: Sendable, Equatable, Hashable {
            /// Filter type (read, write, user, etc.).
            public var type: Kernel.Kqueue.Filter

            /// Filter-specific flags.
            public var flags: Kernel.Kqueue.Filter.Flags

            /// Filter-specific data (e.g., bytes available for read).
            public var data: Kernel.Kqueue.Filter.Data

            /// Creates a filter configuration.
            @inlinable
            public init(
                type: Kernel.Kqueue.Filter,
                flags: Kernel.Kqueue.Filter.Flags = .none,
                data: Kernel.Kqueue.Filter.Data = .zero
            ) {
                self.type = type
                self.flags = flags
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
            self.filter = FilterConfiguration(
                type: Kernel.Kqueue.Filter(rawValue: cEvent.filter),
                flags: Kernel.Kqueue.Filter.Flags(rawValue: cEvent.fflags),
                data: Kernel.Kqueue.Filter.Data(cEvent.data)
            )
            self.flags = Kernel.Kqueue.Flags(rawValue: cEvent.flags)
            self.data = Data(cEvent.udata)
        }

        /// Converts to the Darwin kevent struct.
        @usableFromInline
        internal var cValue: Darwin.kevent {
            var ev = Darwin.kevent()
            ev.ident = id._rawValue
            ev.filter = filter.type.rawValue
            ev.flags = flags.rawValue
            ev.fflags = filter.flags.rawValue
            ev.data = filter.data._rawValue
            ev.udata = UnsafeMutableRawPointer(data)
            return ev
        }
    }

#endif

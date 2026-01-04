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
        }
    }

    // MARK: - C Conversion

    extension Kernel.Event.Poll.Event {
        /// Creates an epoll event from the C struct.
        @usableFromInline
        internal init(_ cEvent: epoll_event) {
            self.events = Kernel.Event.Poll.Events(rawValue: cEvent.events)
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

#endif

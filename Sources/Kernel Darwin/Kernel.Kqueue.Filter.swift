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
        /// Filter types for kqueue events.
        ///
        /// Filters determine what kind of condition triggers the event.
        public struct Filter: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: Int16

            @inlinable
            public init(rawValue: Int16) {
                self.rawValue = rawValue
            }
        }
    }

    extension Kernel.Kqueue.Filter {
        /// Filter for read readiness on a descriptor.
        public static let read = Self(rawValue: Int16(EVFILT_READ))

        /// Filter for write readiness on a descriptor.
        public static let write = Self(rawValue: Int16(EVFILT_WRITE))

        /// User-defined filter for inter-thread wakeup.
        public static let user = Self(rawValue: Int16(EVFILT_USER))
    }

#endif

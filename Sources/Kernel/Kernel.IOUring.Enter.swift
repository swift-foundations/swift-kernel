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

    extension Kernel.IOUring {
        /// Flags for `io_uring_enter`.
        public struct EnterFlags: OptionSet, Sendable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// Wait for events from the CQ ring.
            public static let getEvents = EnterFlags(rawValue: 1 << 0)

            /// Wake up the SQ poll thread.
            public static let sqWakeup = EnterFlags(rawValue: 1 << 1)

            /// Wait for SQ ring space to become available.
            public static let sqWait = EnterFlags(rawValue: 1 << 2)

            /// Use extended argument format (kernel 5.11+).
            public static let extArg = EnterFlags(rawValue: 1 << 3)

            /// Register ring fd with the ring (kernel 5.18+).
            public static let registeredRing = EnterFlags(rawValue: 1 << 4)
        }
    }

#endif

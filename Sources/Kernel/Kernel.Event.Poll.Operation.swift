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

    extension Kernel.Event.Poll {
        /// Operations for `epoll_ctl`.
        public struct Operation: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: Int32

            @inlinable
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
        }
    }

    extension Kernel.Event.Poll.Operation {
        /// Add a file descriptor to the epoll instance.
        public static let add = Self(rawValue: EPOLL_CTL_ADD)

        /// Modify the events for a file descriptor.
        public static let modify = Self(rawValue: EPOLL_CTL_MOD)

        /// Remove a file descriptor from the epoll instance.
        public static let delete = Self(rawValue: EPOLL_CTL_DEL)
    }

#endif

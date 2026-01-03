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

    extension Kernel.IOUring.Setup {
        /// Flags for `io_uring_setup`.
        public struct Flags: OptionSet, Sendable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }
        }
    }

    extension Kernel.IOUring.Setup.Flags {
        /// Perform busy-waiting for I/O completion instead of getting async notification.
        public static let ioPoll = Self(rawValue: 1 << 0)

        /// Create a kernel thread to poll the SQ ring (reduces syscalls).
        public static let sqPoll = Self(rawValue: 1 << 1)

        /// Pin the SQ poll thread to a specific CPU.
        public static let sqAff = Self(rawValue: 1 << 2)

        /// Allow specifying CQ ring size separately from SQ size.
        public static let cqSize = Self(rawValue: 1 << 3)

        /// Clamp SQ/CQ ring sizes to the maximum allowed.
        public static let clamp = Self(rawValue: 1 << 4)

        /// Share the async backend of an existing io_uring instance.
        public static let attachWq = Self(rawValue: 1 << 5)

        /// Start the ring in a disabled state.
        public static let rDisabled = Self(rawValue: 1 << 6)

        /// Let the kernel choose SQ thread CPU.
        public static let submitAll = Self(rawValue: 1 << 7)

        /// Cooperative task running (kernel 5.19+).
        public static let coopTaskrun = Self(rawValue: 1 << 8)

        /// Single-issuer mode for task running (kernel 5.19+).
        public static let taskrunFlag = Self(rawValue: 1 << 9)

        /// Use SQE128 format (kernel 5.19+).
        public static let sqe128 = Self(rawValue: 1 << 10)

        /// Use CQE32 format (kernel 5.19+).
        public static let cqe32 = Self(rawValue: 1 << 11)

        /// Single issuer hint (kernel 6.0+).
        public static let singleIssuer = Self(rawValue: 1 << 12)

        /// Defer taskrun until enter with flag (kernel 6.1+).
        public static let deferTaskrun = Self(rawValue: 1 << 13)
    }

#endif

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
        import Glibc
        import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.IOUring {
        /// Flags for `io_uring_setup`.
        public struct SetupFlags: OptionSet, Sendable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// Perform busy-waiting for I/O completion instead of getting async notification.
            public static let ioPoll = SetupFlags(rawValue: 1 << 0)

            /// Create a kernel thread to poll the SQ ring (reduces syscalls).
            public static let sqPoll = SetupFlags(rawValue: 1 << 1)

            /// Pin the SQ poll thread to a specific CPU.
            public static let sqAff = SetupFlags(rawValue: 1 << 2)

            /// Allow specifying CQ ring size separately from SQ size.
            public static let cqSize = SetupFlags(rawValue: 1 << 3)

            /// Clamp SQ/CQ ring sizes to the maximum allowed.
            public static let clamp = SetupFlags(rawValue: 1 << 4)

            /// Share the async backend of an existing io_uring instance.
            public static let attachWq = SetupFlags(rawValue: 1 << 5)

            /// Start the ring in a disabled state.
            public static let rDisabled = SetupFlags(rawValue: 1 << 6)

            /// Let the kernel choose SQ thread CPU.
            public static let submitAll = SetupFlags(rawValue: 1 << 7)

            /// Cooperative task running (kernel 5.19+).
            public static let coopTaskrun = SetupFlags(rawValue: 1 << 8)

            /// Single-issuer mode for task running (kernel 5.19+).
            public static let taskrunFlag = SetupFlags(rawValue: 1 << 9)

            /// Use SQE128 format (kernel 5.19+).
            public static let sqe128 = SetupFlags(rawValue: 1 << 10)

            /// Use CQE32 format (kernel 5.19+).
            public static let cqe32 = SetupFlags(rawValue: 1 << 11)

            /// Single issuer hint (kernel 6.0+).
            public static let singleIssuer = SetupFlags(rawValue: 1 << 12)

            /// Defer taskrun until enter with flag (kernel 6.1+).
            public static let deferTaskrun = SetupFlags(rawValue: 1 << 13)
        }
    }

    extension Kernel.IOUring {
        /// Swift wrapper for io_uring_params C struct.
        ///
        /// Contains setup parameters passed to io_uring_setup, and ring offsets
        /// returned by the kernel after setup.
        public struct Params: Sendable, Equatable {
            /// Number of submission queue entries (filled by kernel).
            public private(set) var sqEntries: UInt32

            /// Number of completion queue entries (filled by kernel).
            public private(set) var cqEntries: UInt32

            /// Setup flags.
            public var flags: SetupFlags

            /// SQ thread CPU affinity (when using .sqAff flag).
            public var sqThreadCPU: UInt32

            /// SQ thread idle timeout in milliseconds.
            public var sqThreadIdle: UInt32

            /// Ring features supported by kernel (filled by kernel).
            public private(set) var features: UInt32

            /// Submission queue ring offset info (filled by kernel).
            public private(set) var sqOff: SQOffsets

            /// Completion queue ring offset info (filled by kernel).
            public private(set) var cqOff: CQOffsets

            /// Creates io_uring parameters for setup.
            ///
            /// - Parameters:
            ///   - flags: Setup flags to configure the ring.
            ///   - sqThreadCPU: CPU to pin SQ thread to (requires .sqAff flag).
            ///   - sqThreadIdle: SQ thread idle timeout in milliseconds.
            public init(
                flags: SetupFlags = [],
                sqThreadCPU: UInt32 = 0,
                sqThreadIdle: UInt32 = 0
            ) {
                self.sqEntries = 0
                self.cqEntries = 0
                self.flags = flags
                self.sqThreadCPU = sqThreadCPU
                self.sqThreadIdle = sqThreadIdle
                self.features = 0
                self.sqOff = SQOffsets()
                self.cqOff = CQOffsets()
            }

            /// Creates params from the C struct (after setup).
            @usableFromInline
            internal init(_ cParams: io_uring_params) {
                self.sqEntries = cParams.sq_entries
                self.cqEntries = cParams.cq_entries
                self.flags = SetupFlags(rawValue: cParams.flags)
                self.sqThreadCPU = cParams.sq_thread_cpu
                self.sqThreadIdle = cParams.sq_thread_idle
                self.features = cParams.features
                self.sqOff = SQOffsets(cParams.sq_off)
                self.cqOff = CQOffsets(cParams.cq_off)
            }

            /// Converts to the C io_uring_params struct.
            @usableFromInline
            internal var cValue: io_uring_params {
                var params = io_uring_params()
                params.flags = flags.rawValue
                params.sq_thread_cpu = sqThreadCPU
                params.sq_thread_idle = sqThreadIdle
                return params
            }
        }
    }

#endif

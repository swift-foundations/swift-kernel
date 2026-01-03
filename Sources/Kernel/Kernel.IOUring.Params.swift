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
            public var flags: Setup.Flags

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
                flags: Setup.Flags = [],
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
                self.flags = Setup.Flags(rawValue: cParams.flags)
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

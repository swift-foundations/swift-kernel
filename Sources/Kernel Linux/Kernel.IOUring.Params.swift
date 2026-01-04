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

            /// Submission queue thread configuration.
            public var submission: Submission

            /// Ring features supported by kernel (filled by kernel).
            public private(set) var features: UInt32

            /// Submission queue ring offset info (filled by kernel).
            public private(set) var sqOff: Submission.Queue.Offsets

            /// Completion queue ring offset info (filled by kernel).
            public private(set) var cqOff: Completion.Queue.Offsets

            /// Creates io_uring parameters for setup.
            ///
            /// - Parameters:
            ///   - flags: Setup flags to configure the ring.
            ///   - submission: Submission queue thread configuration.
            public init(
                flags: Setup.Flags = [],
                submission: Submission = Submission()
            ) {
                self.sqEntries = 0
                self.cqEntries = 0
                self.flags = flags
                self.submission = submission
                self.features = 0
                self.sqOff = Submission.Queue.Offsets()
                self.cqOff = Completion.Queue.Offsets()
            }

            /// Creates params from the C struct (after setup).
            internal init(_ cParams: io_uring_params) {
                self.sqEntries = cParams.sq_entries
                self.cqEntries = cParams.cq_entries
                self.flags = Setup.Flags(rawValue: cParams.flags)
                self.submission = Submission(
                    thread: Submission.Thread(
                        cpu: cParams.sq_thread_cpu,
                        idle: cParams.sq_thread_idle
                    )
                )
                self.features = cParams.features
                self.sqOff = Submission.Queue.Offsets(cParams.sq_off)
                self.cqOff = Completion.Queue.Offsets(cParams.cq_off)
            }

            /// Converts to the C io_uring_params struct.
            internal var cValue: io_uring_params {
                var params = io_uring_params()
                params.flags = flags.rawValue
                params.sq_thread_cpu = submission.thread.cpu
                params.sq_thread_idle = submission.thread.idle
                return params
            }
        }
    }

    // MARK: - Submission Thread Configuration

    extension Kernel.IOUring.Params {
        /// Submission queue configuration.
        public struct Submission: Sendable, Equatable {
            /// Thread configuration for submission queue polling.
            public var thread: Thread

            /// Creates submission configuration.
            public init(thread: Thread = Thread()) {
                self.thread = thread
            }

            /// Thread configuration for submission queue polling.
            public struct Thread: Sendable, Equatable {
                /// CPU affinity (when using .sqAff flag).
                public var cpu: UInt32

                /// Idle timeout in milliseconds.
                public var idle: UInt32

                /// Creates thread configuration.
                public init(cpu: UInt32 = 0, idle: UInt32 = 0) {
                    self.cpu = cpu
                    self.idle = idle
                }
            }
        }
    }

#endif

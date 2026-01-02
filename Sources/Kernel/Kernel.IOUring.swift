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
        public import Musl
    #endif

    extension Kernel {
        /// Raw io_uring syscall wrappers (Linux only).
        ///
        /// io_uring is a high-performance asynchronous I/O interface for Linux (kernel 5.1+).
        /// This namespace provides policy-free syscall wrappers.
        ///
        /// Higher layers (swift-io) build ring memory management, SQ/CQ indexing,
        /// and operation dispatch on top of these primitives.
        public enum IOUring {}
    }

    // MARK: - Error Type

    extension Kernel.IOUring {
        /// Errors from io_uring operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create io_uring instance.
            case setupFailed(errno: Int32)

            /// Failed to submit/wait (io_uring_enter).
            case enterFailed(errno: Int32)

            /// Failed to register resources.
            case registerFailed(errno: Int32)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.IOUring.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .setupFailed(let errno):
                return "io_uring_setup failed (errno: \(errno))"
            case .enterFailed(let errno):
                return "io_uring_enter failed (errno: \(errno))"
            case .registerFailed(let errno):
                return "io_uring_register failed (errno: \(errno))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

    // MARK: - Setup Flags

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

    // MARK: - Enter Flags

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

    // MARK: - Register Opcodes

    extension Kernel.IOUring {
        /// Opcodes for `io_uring_register`.
        public struct RegisterOpcode: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// Register buffers for zero-copy I/O.
            public static let registerBuffers = RegisterOpcode(rawValue: 0)

            /// Unregister previously registered buffers.
            public static let unregisterBuffers = RegisterOpcode(rawValue: 1)

            /// Register file descriptors.
            public static let registerFiles = RegisterOpcode(rawValue: 2)

            /// Unregister previously registered files.
            public static let unregisterFiles = RegisterOpcode(rawValue: 3)

            /// Register an eventfd for CQ notifications.
            public static let registerEventfd = RegisterOpcode(rawValue: 4)

            /// Unregister the eventfd.
            public static let unregisterEventfd = RegisterOpcode(rawValue: 5)

            /// Update registered files.
            public static let registerFilesUpdate = RegisterOpcode(rawValue: 6)

            /// Register eventfd for async notification.
            public static let registerEventfdAsync = RegisterOpcode(rawValue: 7)

            /// Probe supported operations.
            public static let registerProbe = RegisterOpcode(rawValue: 8)

            /// Register personality (credentials).
            public static let registerPersonality = RegisterOpcode(rawValue: 9)

            /// Unregister personality.
            public static let unregisterPersonality = RegisterOpcode(rawValue: 10)

            /// Enable a disabled ring.
            public static let enableRings = RegisterOpcode(rawValue: 11)
        }
    }

    // MARK: - Syscalls

    extension Kernel.IOUring {
        /// Creates a new io_uring instance.
        ///
        /// - Parameters:
        ///   - entries: Number of SQ entries (rounded up to power of 2).
        ///   - params: Parameters struct (modified on return with ring offsets).
        /// - Returns: File descriptor for the io_uring instance.
        /// - Throws: `Error.setupFailed` if creation fails.
        @inlinable
        public static func setup(
            entries: UInt32,
            params: inout io_uring_params
        ) throws(Error) -> Kernel.Descriptor {
            let fd = swift_io_uring_setup(entries, &params)
            guard fd >= 0 else {
                throw .setupFailed(errno: errno)
            }
            return Kernel.Descriptor(rawValue: fd)
        }

        /// Submits operations and/or waits for completions.
        ///
        /// - Parameters:
        ///   - fd: io_uring file descriptor.
        ///   - toSubmit: Number of SQEs to submit.
        ///   - minComplete: Minimum completions to wait for.
        ///   - flags: Enter flags.
        /// - Returns: Number of SQEs submitted.
        /// - Throws: `Error.enterFailed` on failure, `Error.interrupted` on EINTR.
        @inlinable
        public static func enter(
            _ fd: Kernel.Descriptor,
            toSubmit: UInt32,
            minComplete: UInt32,
            flags: EnterFlags
        ) throws(Error) -> Int {
            let result = swift_io_uring_enter(
                fd.rawValue,
                toSubmit,
                minComplete,
                flags.rawValue,
                nil
            )
            guard result >= 0 else {
                let err = errno
                if err == EINTR { throw .interrupted }
                throw .enterFailed(errno: err)
            }
            return Int(result)
        }

        /// Registers resources with the io_uring instance.
        ///
        /// - Parameters:
        ///   - fd: io_uring file descriptor.
        ///   - opcode: The registration operation to perform.
        ///   - argument: Pointer to the arguments for the operation.
        ///   - count: Number of arguments.
        /// - Throws: `Error.registerFailed` on failure.
        @inlinable
        public static func register(
            _ fd: Kernel.Descriptor,
            opcode: RegisterOpcode,
            argument: UnsafeMutableRawPointer?,
            count: UInt32
        ) throws(Error) {
            let result = swift_io_uring_register(
                fd.rawValue,
                opcode.rawValue,
                argument,
                count
            )
            guard result >= 0 else {
                throw .registerFailed(errno: errno)
            }
        }

        /// Closes an io_uring instance.
        ///
        /// Uses `Kernel.Close.close()` for consistency. Ignores errors.
        ///
        /// - Parameter fd: The io_uring file descriptor to close.
        @inlinable
        public static func close(_ fd: Kernel.Descriptor) {
            try? Kernel.Close.close(fd)
        }
    }

#endif

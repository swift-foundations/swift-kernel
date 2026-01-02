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

    // MARK: - Kernel.Error Conversion

    extension Kernel.IOUring.Error {
        /// Converts this io_uring error to a `Kernel.Error`.
        ///
        /// Maps to semantic cases where possible, falls back to `.platform` otherwise.
        public var asKernelError: Kernel.Error {
            switch self {
            case .setupFailed(let errno):
                return .platform(code: errno, message: "io_uring_setup failed")
            case .enterFailed(let errno):
                return .platform(code: errno, message: "io_uring_enter failed")
            case .registerFailed(let errno):
                return .platform(code: errno, message: "io_uring_register failed")
            case .interrupted:
                return .resource(.interrupted)
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

    // MARK: - Params Type

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

    extension Kernel.IOUring {
        /// Offsets for submission queue ring mapping.
        public struct SQOffsets: Sendable, Equatable {
            public let head: UInt32
            public let tail: UInt32
            public let ringMask: UInt32
            public let ringEntries: UInt32
            public let flags: UInt32
            public let dropped: UInt32
            public let array: UInt32

            @usableFromInline
            internal init() {
                self.head = 0
                self.tail = 0
                self.ringMask = 0
                self.ringEntries = 0
                self.flags = 0
                self.dropped = 0
                self.array = 0
            }

            @usableFromInline
            internal init(_ off: io_sqring_offsets) {
                self.head = off.head
                self.tail = off.tail
                self.ringMask = off.ring_mask
                self.ringEntries = off.ring_entries
                self.flags = off.flags
                self.dropped = off.dropped
                self.array = off.array
            }
        }

        /// Offsets for completion queue ring mapping.
        public struct CQOffsets: Sendable, Equatable {
            public let head: UInt32
            public let tail: UInt32
            public let ringMask: UInt32
            public let ringEntries: UInt32
            public let overflow: UInt32
            public let cqes: UInt32
            public let flags: UInt32

            @usableFromInline
            internal init() {
                self.head = 0
                self.tail = 0
                self.ringMask = 0
                self.ringEntries = 0
                self.overflow = 0
                self.cqes = 0
                self.flags = 0
            }

            @usableFromInline
            internal init(_ off: io_cqring_offsets) {
                self.head = off.head
                self.tail = off.tail
                self.ringMask = off.ring_mask
                self.ringEntries = off.ring_entries
                self.overflow = off.overflow
                self.cqes = off.cqes
                self.flags = off.flags
            }
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
            params: inout Params
        ) throws(Error) -> Kernel.Descriptor {
            var cParams = params.cValue
            let fd = _cIoUringSetup(entries, &cParams)
            guard fd >= 0 else {
                throw .setupFailed(errno: errno)
            }
            // Update params with kernel-filled values
            params = Params(cParams)
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
            let result = _cIoUringEnter(
                fd.rawValue,
                toSubmit,
                minComplete,
                flags.rawValue,
                nil,
                0
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
            let result = _cIoUringRegister(
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

    // MARK: - Mmap Offsets

    extension Kernel.IOUring {
        /// Mmap offsets for io_uring ring buffers.
        ///
        /// These magic offset values are passed to `mmap()` to map different
        /// parts of the io_uring ring structure:
        ///
        /// - `sqRing`: Maps the submission queue ring (head, tail, mask, flags, array)
        /// - `cqRing`: Maps the completion queue ring (head, tail, mask, cqes)
        /// - `sqes`: Maps the submission queue entry array
        ///
        /// ## Usage
        ///
        /// ```swift
        /// // Map the SQ ring
        /// let sqRingPtr = try Kernel.Mmap.map(
        ///     length: sqRingSize,
        ///     protection: .readWrite,
        ///     flags: .shared,
        ///     fd: ringFd,
        ///     offset: Kernel.IOUring.MmapOffset.sqRing
        /// )
        /// ```
        public enum MmapOffset {
            /// Offset for mapping the submission queue ring.
            ///
            /// Value: `IORING_OFF_SQ_RING` (0)
            public static let sqRing: Int64 = 0

            /// Offset for mapping the completion queue ring.
            ///
            /// Value: `IORING_OFF_CQ_RING` (0x8000000)
            public static let cqRing: Int64 = 0x8000000

            /// Offset for mapping the submission queue entries array.
            ///
            /// Value: `IORING_OFF_SQES` (0x10000000)
            public static let sqes: Int64 = 0x1000_0000
        }
    }

    // MARK: - Runtime Detection

    extension Kernel.IOUring {
        /// Whether io_uring is available on this system.
        ///
        /// Checks by attempting `io_uring_setup` with minimal parameters.
        /// Result is cached after first call.
        ///
        /// Can be disabled via the `IO_URING_DISABLED=1` environment variable.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// if Kernel.IOUring.isSupported {
        ///     // Use io_uring backend
        /// } else {
        ///     // Fall back to epoll or other backend
        /// }
        /// ```
        public static var isSupported: Bool {
            _isSupported
        }

        /// Cached support check.
        private static let _isSupported: Bool = {
            // Check if disabled via environment
            if Kernel.Environment.isSet("IO_URING_DISABLED", to: "1") {
                return false
            }

            // Try to set up a minimal ring to check support
            var params = Params()
            do {
                let fd = try setup(entries: 1, params: &params)
                close(fd)
                return true
            } catch {
                return false
            }
        }()
    }

#endif

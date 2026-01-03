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
        public import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.IOUring {
        /// Swift wrapper for io_uring submission queue entry.
        ///
        /// An SQE describes an I/O operation to be performed by the kernel.
        /// This wrapper provides a Swift-native interface to the C `io_uring_sqe` struct.
        ///
        /// ## Usage
        ///
        /// SQEs are typically filled in-place in the SQ ring buffer:
        /// ```swift
        /// let sqePtr = ring.sqes.advanced(by: index)
        /// var sqe = Kernel.IOUring.SQE()
        /// sqe.setRead(fd: fd, buffer: buffer, offset: 0, userData: id)
        /// sqePtr.pointee = sqe.cValue
        /// ```
        ///
        /// ## Thread Safety
        ///
        /// SQEs are value types that wrap a C struct. They should be filled
        /// on the poll thread and written to the shared ring buffer.
        public struct SQE: Sendable {
            /// The underlying C struct.
            public var cValue: io_uring_sqe

            /// Creates an empty SQE (zeroed).
            @inlinable
            public init() {
                self.cValue = io_uring_sqe()
            }

            /// Creates an SQE from a C struct.
            @inlinable
            public init(_ cValue: io_uring_sqe) {
                self.cValue = cValue
            }
        }
    }

    // MARK: - Accessors

    extension Kernel.IOUring.SQE {
        /// The operation code.
        @inlinable
        public var opcode: Kernel.IOUring.Opcode {
            get { Kernel.IOUring.Opcode(rawValue: cValue.opcode) }
            set { cValue.opcode = newValue.rawValue }
        }

        /// SQE flags.
        @inlinable
        public var flags: UInt8 {
            get { cValue.flags }
            set { cValue.flags = newValue }
        }

        /// I/O priority.
        @inlinable
        public var ioprio: UInt16 {
            get { cValue.ioprio }
            set { cValue.ioprio = newValue }
        }

        /// File descriptor for the operation.
        @inlinable
        public var fd: Int32 {
            get { cValue.fd }
            set { cValue.fd = newValue }
        }

        /// File offset (or flags for some operations).
        @inlinable
        public var offset: UInt64 {
            get { cValue.off }
            set { cValue.off = newValue }
        }

        /// Buffer address or other address field.
        @inlinable
        public var addr: UInt64 {
            get { cValue.addr }
            set { cValue.addr = newValue }
        }

        /// Buffer length.
        @inlinable
        public var len: UInt32 {
            get { cValue.len }
            set { cValue.len = newValue }
        }

        /// Operation-specific flags.
        ///
        /// Note: Uses Int32 to match Linux kernel's `__kernel_rwf_t` type.
        @inlinable
        public var opFlags: Int32 {
            get { cValue.rw_flags }
            set { cValue.rw_flags = newValue }
        }

        /// User data returned with completion.
        @inlinable
        public var userData: UInt64 {
            get { cValue.user_data }
            set { cValue.user_data = newValue }
        }

        /// Buffer index (for registered buffers).
        @inlinable
        public var bufferIndex: UInt16 {
            get { cValue.buf_index }
            set { cValue.buf_index = newValue }
        }

        /// Buffer group (for buffer selection).
        @inlinable
        public var bufferGroup: UInt16 {
            get { cValue.buf_group }
            set { cValue.buf_group = newValue }
        }

        /// Personality ID (for credentials).
        @inlinable
        public var personality: UInt16 {
            get { cValue.personality }
            set { cValue.personality = newValue }
        }
    }

    // MARK: - SQE Flags

    extension Kernel.IOUring.SQE {
        /// Flags for SQE behavior.
        public struct Flags: OptionSet, Sendable {
            public let rawValue: UInt8

            @inlinable
            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }

            /// Use fixed file descriptor from registered files.
            public static let fixedFile = Flags(rawValue: 1 << 0)

            /// Issue operation after previous SQE completes.
            public static let ioLink = Flags(rawValue: 1 << 1)

            /// Like ioLink, but also links on failure.
            public static let ioHardlink = Flags(rawValue: 1 << 2)

            /// Force async execution (never complete inline).
            public static let async = Flags(rawValue: 1 << 3)

            /// Select buffer from provided buffer group.
            public static let bufferSelect = Flags(rawValue: 1 << 4)

            /// Don't post CQE if operation completes successfully (kernel 5.17+).
            public static let cqeSkipSuccess = Flags(rawValue: 1 << 5)
        }
    }

    // MARK: - Operation Preparation

    extension Kernel.IOUring.SQE {
        /// Accessor for preparing SQE operations.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// var sqe = Kernel.IOUring.SQE()
        /// sqe.prepare.read(fd: fd, buffer: buffer, length: len, offset: 0, userData: id)
        /// ```
        @inlinable
        public var prepare: Prepare {
            get { Prepare(sqe: self) }
            set { self = newValue.sqe }
        }

        /// Helper for preparing SQE operations.
        public struct Prepare {
            public var sqe: SQE

            @inlinable
            init(sqe: SQE) {
                self.sqe = sqe
            }

            /// Configures this SQE for a no-op operation.
            ///
            /// - Parameter userData: User data to return with completion.
            @inlinable
            public mutating func nop(userData: UInt64) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .nop
                sqe.userData = userData
            }

            /// Configures this SQE for a read operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to read from.
            ///   - buffer: Buffer pointer to read into.
            ///   - length: Number of bytes to read.
            ///   - offset: File offset (-1 for current position).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func read(
                fd: Int32,
                buffer: UnsafeMutableRawPointer,
                length: UInt32,
                offset: Int64,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .read
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: buffer))
                sqe.len = length
                sqe.offset = offset >= 0 ? UInt64(bitPattern: offset) : UInt64.max
                sqe.userData = userData
            }

            /// Configures this SQE for a write operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to write to.
            ///   - buffer: Buffer pointer containing data to write.
            ///   - length: Number of bytes to write.
            ///   - offset: File offset (-1 for current position).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func write(
                fd: Int32,
                buffer: UnsafeRawPointer,
                length: UInt32,
                offset: Int64,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .write
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: buffer))
                sqe.len = length
                sqe.offset = offset >= 0 ? UInt64(bitPattern: offset) : UInt64.max
                sqe.userData = userData
            }

            /// Configures this SQE for a cancel operation.
            ///
            /// - Parameters:
            ///   - targetUserData: User data of the operation to cancel.
            ///   - userData: User data to return with this cancel's completion.
            @inlinable
            public mutating func cancel(
                targetUserData: UInt64,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .asyncCancel
                sqe.addr = targetUserData
                sqe.userData = userData
            }

            /// Configures this SQE for an fsync operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to sync.
            ///   - datasync: If true, only sync data (not metadata).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func fsync(
                fd: Int32,
                datasync: Bool,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .fsync
                sqe.fd = fd
                if datasync {
                    sqe.opFlags = 1  // IORING_FSYNC_DATASYNC
                }
                sqe.userData = userData
            }

            /// Configures this SQE for a close operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to close.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func close(
                fd: Int32,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .close
                sqe.fd = fd
                sqe.userData = userData
            }

            /// Configures this SQE for an accept operation.
            ///
            /// - Parameters:
            ///   - fd: Listening socket file descriptor.
            ///   - addr: Optional pointer to sockaddr buffer.
            ///   - addrLen: Optional pointer to sockaddr length.
            ///   - flags: Accept flags.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func accept(
                fd: Int32,
                addr: UnsafeMutableRawPointer?,
                addrLen: UnsafeMutablePointer<UInt32>?,
                flags: Int32,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .accept
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: addr))
                sqe.offset = UInt64(UInt(bitPattern: addrLen))
                sqe.opFlags = flags
                sqe.userData = userData
            }

            /// Configures this SQE for a connect operation.
            ///
            /// - Parameters:
            ///   - fd: Socket file descriptor.
            ///   - addr: Pointer to sockaddr.
            ///   - addrLen: Length of sockaddr.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func connect(
                fd: Int32,
                addr: UnsafeRawPointer,
                addrLen: UInt32,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .connect
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: addr))
                sqe.offset = UInt64(addrLen)
                sqe.userData = userData
            }

            /// Configures this SQE for a send operation.
            ///
            /// - Parameters:
            ///   - fd: Socket file descriptor.
            ///   - buffer: Buffer pointer containing data to send.
            ///   - length: Number of bytes to send.
            ///   - flags: Send flags.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func send(
                fd: Int32,
                buffer: UnsafeRawPointer,
                length: UInt32,
                flags: Int32,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .send
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: buffer))
                sqe.len = length
                sqe.opFlags = flags
                sqe.userData = userData
            }

            /// Configures this SQE for a recv operation.
            ///
            /// - Parameters:
            ///   - fd: Socket file descriptor.
            ///   - buffer: Buffer pointer to receive into.
            ///   - length: Maximum bytes to receive.
            ///   - flags: Recv flags.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func recv(
                fd: Int32,
                buffer: UnsafeMutableRawPointer,
                length: UInt32,
                flags: Int32,
                userData: UInt64
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .recv
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: buffer))
                sqe.len = length
                sqe.opFlags = flags
                sqe.userData = userData
            }
        }
    }

#endif

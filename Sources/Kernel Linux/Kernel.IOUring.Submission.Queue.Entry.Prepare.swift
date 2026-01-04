// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//
public import Kernel_Primitives


#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.IOUring.Submission.Queue.Entry {
        /// Helper for preparing submission queue entry operations.
        public struct Prepare {
            public var entry: Kernel.IOUring.Submission.Queue.Entry

            @inlinable
            init(entry: Kernel.IOUring.Submission.Queue.Entry) {
                self.entry = entry
            }

            /// Configures this entry for a no-op operation.
            ///
            /// - Parameter userData: User data to return with completion.
            @inlinable
            public mutating func nop(userData: Kernel.IOUring.UserData) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .nop
                entry.userData = userData
            }

            /// Configures this entry for a read operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to read from.
            ///   - buffer: Buffer pointer to read into.
            ///   - length: Number of bytes to read.
            ///   - offset: File offset (use `.current` for current position).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func read(
                fd: Kernel.Descriptor,
                buffer: UnsafeMutableRawPointer,
                length: Kernel.IOUring.Length,
                offset: Kernel.IOUring.Offset,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .read
                entry.fd = fd
                entry.addr = UInt64(UInt(bitPattern: buffer))
                entry.len = length
                entry.offset = offset
                entry.userData = userData
            }

            /// Configures this entry for a write operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to write to.
            ///   - buffer: Buffer pointer containing data to write.
            ///   - length: Number of bytes to write.
            ///   - offset: File offset (use `.current` for current position).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func write(
                fd: Kernel.Descriptor,
                buffer: UnsafeRawPointer,
                length: Kernel.IOUring.Length,
                offset: Kernel.IOUring.Offset,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .write
                entry.fd = fd
                entry.addr = UInt64(UInt(bitPattern: buffer))
                entry.len = length
                entry.offset = offset
                entry.userData = userData
            }

            /// Configures this entry for a cancel operation.
            ///
            /// - Parameters:
            ///   - targetUserData: User data of the operation to cancel.
            ///   - userData: User data to return with this cancel's completion.
            @inlinable
            public mutating func cancel(
                targetUserData: Kernel.IOUring.UserData,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .asyncCancel
                entry.addr = targetUserData.rawValue
                entry.userData = userData
            }

            /// Configures this entry for an fsync operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to sync.
            ///   - datasync: If true, only sync data (not metadata).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func fsync(
                fd: Kernel.Descriptor,
                datasync: Bool,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .fsync
                entry.fd = fd
                if datasync {
                    entry.opFlags = 1  // IORING_FSYNC_DATASYNC
                }
                entry.userData = userData
            }

            /// Configures this entry for a close operation.
            ///
            /// - Parameters:
            ///   - fd: File descriptor to close.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func close(
                fd: Kernel.Descriptor,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .close
                entry.fd = fd
                entry.userData = userData
            }

            /// Configures this entry for an accept operation.
            ///
            /// - Parameters:
            ///   - fd: Listening socket file descriptor.
            ///   - addr: Optional pointer to sockaddr buffer.
            ///   - addrLen: Optional pointer to sockaddr length.
            ///   - flags: Accept flags.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func accept(
                fd: Kernel.Descriptor,
                addr: UnsafeMutableRawPointer?,
                addrLen: UnsafeMutablePointer<UInt32>?,
                flags: Int32,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .accept
                entry.fd = fd
                entry.addr = UInt64(UInt(bitPattern: addr))
                entry.offset = Kernel.IOUring.Offset(rawValue: UInt64(UInt(bitPattern: addrLen)))
                entry.opFlags = flags
                entry.userData = userData
            }

            /// Configures this entry for a connect operation.
            ///
            /// - Parameters:
            ///   - fd: Socket file descriptor.
            ///   - addr: Pointer to sockaddr.
            ///   - addrLen: Length of sockaddr.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func connect(
                fd: Kernel.Descriptor,
                addr: UnsafeRawPointer,
                addrLen: UInt32,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .connect
                entry.fd = fd
                entry.addr = UInt64(UInt(bitPattern: addr))
                entry.offset = Kernel.IOUring.Offset(rawValue: UInt64(addrLen))
                entry.userData = userData
            }

            /// Configures this entry for a send operation.
            ///
            /// - Parameters:
            ///   - fd: Socket file descriptor.
            ///   - buffer: Buffer pointer containing data to send.
            ///   - length: Number of bytes to send.
            ///   - flags: Send flags.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func send(
                fd: Kernel.Descriptor,
                buffer: UnsafeRawPointer,
                length: Kernel.IOUring.Length,
                flags: Int32,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .send
                entry.fd = fd
                entry.addr = UInt64(UInt(bitPattern: buffer))
                entry.len = length
                entry.opFlags = flags
                entry.userData = userData
            }

            /// Configures this entry for a recv operation.
            ///
            /// - Parameters:
            ///   - fd: Socket file descriptor.
            ///   - buffer: Buffer pointer to receive into.
            ///   - length: Maximum bytes to receive.
            ///   - flags: Recv flags.
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func recv(
                fd: Kernel.Descriptor,
                buffer: UnsafeMutableRawPointer,
                length: Kernel.IOUring.Length,
                flags: Int32,
                userData: Kernel.IOUring.UserData
            ) {
                entry.cValue = io_uring_sqe()
                entry.opcode = .recv
                entry.fd = fd
                entry.addr = UInt64(UInt(bitPattern: buffer))
                entry.len = length
                entry.opFlags = flags
                entry.userData = userData
            }
        }
    }

    // MARK: - Prepare Accessor

    extension Kernel.IOUring.Submission.Queue.Entry {
        /// Accessor for preparing entry operations.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// var entry = Kernel.IOUring.Submission.Queue.Entry()
        /// entry.prepare.read(fd: fd, buffer: buffer, length: len, offset: 0, userData: id)
        /// ```
        @inlinable
        public var prepare: Prepare {
            get { Prepare(entry: self) }
            set { self = newValue.entry }
        }
    }

#endif

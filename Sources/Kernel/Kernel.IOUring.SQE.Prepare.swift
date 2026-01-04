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

    extension Kernel.IOUring.SQE {
        /// Helper for preparing SQE operations.
        public struct Prepare {
            public var sqe: Kernel.IOUring.SQE

            @inlinable
            init(sqe: Kernel.IOUring.SQE) {
                self.sqe = sqe
            }

            /// Configures this SQE for a no-op operation.
            ///
            /// - Parameter userData: User data to return with completion.
            @inlinable
            public mutating func nop(userData: UserData) {
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
            ///   - offset: File offset (use `.current` for current position).
            ///   - userData: User data to return with completion.
            @inlinable
            public mutating func read(
                fd: Kernel.Descriptor,
                buffer: UnsafeMutableRawPointer,
                length: Length,
                offset: Offset,
                userData: UserData
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .read
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: buffer))
                sqe.len = length
                sqe.offset = offset
                sqe.userData = userData
            }

            /// Configures this SQE for a write operation.
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
                length: Length,
                offset: Offset,
                userData: UserData
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .write
                sqe.fd = fd
                sqe.addr = UInt64(UInt(bitPattern: buffer))
                sqe.len = length
                sqe.offset = offset
                sqe.userData = userData
            }

            /// Configures this SQE for a cancel operation.
            ///
            /// - Parameters:
            ///   - targetUserData: User data of the operation to cancel.
            ///   - userData: User data to return with this cancel's completion.
            @inlinable
            public mutating func cancel(
                targetUserData: UserData,
                userData: UserData
            ) {
                sqe.cValue = io_uring_sqe()
                sqe.opcode = .asyncCancel
                sqe.addr = targetUserData.rawValue
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
                fd: Kernel.Descriptor,
                datasync: Bool,
                userData: UserData
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
                fd: Kernel.Descriptor,
                userData: UserData
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
                fd: Kernel.Descriptor,
                addr: UnsafeMutableRawPointer?,
                addrLen: UnsafeMutablePointer<UInt32>?,
                flags: Int32,
                userData: UserData
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
                fd: Kernel.Descriptor,
                addr: UnsafeRawPointer,
                addrLen: UInt32,
                userData: UserData
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
                fd: Kernel.Descriptor,
                buffer: UnsafeRawPointer,
                length: Length,
                flags: Int32,
                userData: UserData
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
                fd: Kernel.Descriptor,
                buffer: UnsafeMutableRawPointer,
                length: Length,
                flags: Int32,
                userData: UserData
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

    // MARK: - Prepare Accessor

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
    }

#endif

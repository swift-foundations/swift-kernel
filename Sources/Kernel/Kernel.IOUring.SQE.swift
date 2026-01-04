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
        public var priority: Priority {
            get { Priority(rawValue: cValue.ioprio) }
            set { cValue.ioprio = newValue.rawValue }
        }

        /// File descriptor for the operation.
        @inlinable
        public var fd: Kernel.Descriptor {
            get { Kernel.Descriptor(rawValue: cValue.fd) }
            set { cValue.fd = newValue.rawValue }
        }

        /// File offset for read/write operations.
        @inlinable
        public var offset: Offset {
            get { Offset(rawValue: cValue.off) }
            set { cValue.off = newValue.rawValue }
        }

        /// Buffer address or other address field.
        @inlinable
        public var addr: UInt64 {
            get { cValue.addr }
            set { cValue.addr = newValue }
        }

        /// Buffer length.
        @inlinable
        public var len: Length {
            get { Length(rawValue: cValue.len) }
            set { cValue.len = newValue.rawValue }
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
        public var userData: UserData {
            get { UserData(rawValue: cValue.user_data) }
            set { cValue.user_data = newValue.rawValue }
        }

        /// Buffer index (for registered buffers).
        @inlinable
        public var bufferIndex: Buffer.Index {
            get { Buffer.Index(rawValue: cValue.buf_index) }
            set { cValue.buf_index = newValue.rawValue }
        }

        /// Buffer group (for buffer selection).
        @inlinable
        public var bufferGroup: Buffer.Group {
            get { Buffer.Group(rawValue: cValue.buf_group) }
            set { cValue.buf_group = newValue.rawValue }
        }

        /// Personality ID (for credentials).
        @inlinable
        public var personality: Personality.ID {
            get { Personality.ID(rawValue: cValue.personality) }
            set { cValue.personality = newValue.rawValue }
        }
    }

#endif

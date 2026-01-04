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

#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.IOUring.Submission.Queue {
        /// Swift wrapper for io_uring submission queue entry.
        ///
        /// An Entry describes an I/O operation to be performed by the kernel.
        /// This wrapper provides a Swift-native interface to the C `io_uring_sqe` struct.
        ///
        /// ## Usage
        ///
        /// Entries are typically filled in-place in the submission queue ring buffer:
        /// ```swift
        /// let entryPtr = ring.sqes.advanced(by: index)
        /// var entry = Kernel.IOUring.Submission.Queue.Entry()
        /// entry.setRead(fd: fd, buffer: buffer, offset: 0, userData: id)
        /// entryPtr.pointee = entry.cValue
        /// ```
        ///
        /// ## Thread Safety
        ///
        /// Entries are value types that wrap a C struct. They should be filled
        /// on the poll thread and written to the shared ring buffer.
        public struct Entry: Sendable {
            /// The underlying C struct.
            public var cValue: io_uring_sqe

            /// Creates an empty Entry (zeroed).
            @inlinable
            public init() {
                self.cValue = io_uring_sqe()
            }

            /// Creates an Entry from a C struct.
            @inlinable
            public init(_ cValue: io_uring_sqe) {
                self.cValue = cValue
            }
        }
    }

    // MARK: - Accessors

    extension Kernel.IOUring.Submission.Queue.Entry {
        /// The operation code.
        @inlinable
        public var opcode: Kernel.IOUring.Opcode {
            get { Kernel.IOUring.Opcode(rawValue: cValue.opcode) }
            set { cValue.opcode = newValue.rawValue }
        }

        /// Entry flags.
        @inlinable
        public var flags: UInt8 {
            get { cValue.flags }
            set { cValue.flags = newValue }
        }

        /// I/O priority.
        @inlinable
        public var priority: Kernel.IOUring.Priority {
            get { Kernel.IOUring.Priority(rawValue: cValue.ioprio) }
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
        public var offset: Kernel.IOUring.Offset {
            get { Kernel.IOUring.Offset(rawValue: cValue.off) }
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
        public var len: Kernel.IOUring.Length {
            get { Kernel.IOUring.Length(rawValue: cValue.len) }
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
        public var userData: Kernel.IOUring.UserData {
            get { Kernel.IOUring.UserData(rawValue: cValue.user_data) }
            set { cValue.user_data = newValue.rawValue }
        }

        /// Buffer index (for registered buffers).
        @inlinable
        public var bufferIndex: Kernel.IOUring.Buffer.Index {
            get { Kernel.IOUring.Buffer.Index(rawValue: cValue.buf_index) }
            set { cValue.buf_index = newValue.rawValue }
        }

        /// Buffer group (for buffer selection).
        @inlinable
        public var bufferGroup: Kernel.IOUring.Buffer.Group {
            get { Kernel.IOUring.Buffer.Group(rawValue: cValue.buf_group) }
            set { cValue.buf_group = newValue.rawValue }
        }

        /// Personality ID (for credentials).
        @inlinable
        public var personality: Kernel.IOUring.Personality.ID {
            get { Kernel.IOUring.Personality.ID(rawValue: cValue.personality) }
            set { cValue.personality = newValue.rawValue }
        }
    }

#endif

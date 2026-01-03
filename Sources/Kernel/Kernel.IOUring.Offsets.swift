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

#endif

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

#if os(Windows)
    public import WinSDK

    extension Kernel.IOCP {
        /// Swift wrapper for Windows OVERLAPPED_ENTRY structure.
        ///
        /// Used with `GetQueuedCompletionStatusEx` for batched completion retrieval.
        public struct Entry: @unchecked Sendable {
            /// The underlying Windows OVERLAPPED_ENTRY structure.
            @usableFromInline
            internal var raw: OVERLAPPED_ENTRY

            /// Creates a zero-initialized entry.
            @inlinable
            public init() {
                raw = OVERLAPPED_ENTRY()
            }
        }
    }

    // MARK: - Accessors

    extension Kernel.IOCP.Entry {
        /// Pointer to the OVERLAPPED structure for this completion.
        @inlinable
        internal var overlapped: UnsafeMutablePointer<OVERLAPPED>? {
            raw.lpOverlapped
        }

        /// The completion key associated with the file handle.
        @inlinable
        public var key: Kernel.IOCP.Completion.Key {
            Kernel.IOCP.Completion.Key(rawValue: raw.lpCompletionKey)
        }
    }

    // MARK: - Bytes Accessor

    extension Kernel.IOCP.Entry {
        /// Accessor for byte-related properties.
        public var bytes: Bytes { Bytes(entry: self) }

        /// Byte-related properties for completion entry.
        public struct Bytes: Sendable {
            @usableFromInline
            let entry: Kernel.IOCP.Entry

            @usableFromInline
            init(entry: Kernel.IOCP.Entry) {
                self.entry = entry
            }

            /// Number of bytes transferred in the completed operation.
            @inlinable
            public var transferred: UInt32 {
                entry.raw.dwNumberOfBytesTransferred
            }
        }
    }

#endif

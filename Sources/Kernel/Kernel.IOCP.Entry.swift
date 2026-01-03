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

#if os(Windows)
public import WinSDK

extension Kernel.IOCP {
    /// Swift wrapper for Windows OVERLAPPED_ENTRY structure.
    ///
    /// Used with `GetQueuedCompletionStatusEx` for batched completion retrieval.
    public struct Entry: @unchecked Sendable {
        /// The underlying Windows OVERLAPPED_ENTRY structure.
        public var raw: OVERLAPPED_ENTRY

        /// Creates a zero-initialized entry.
        @inlinable
        public init() {
            raw = OVERLAPPED_ENTRY()
        }
    }
}

// MARK: - Accessors

extension Kernel.IOCP.Entry {
    /// Number of bytes transferred in the completed operation.
    @inlinable
    public var bytesTransferred: UInt32 {
        raw.dwNumberOfBytesTransferred
    }

    /// Pointer to the OVERLAPPED structure for this completion.
    @inlinable
    public var overlapped: UnsafeMutablePointer<OVERLAPPED>? {
        raw.lpOverlapped
    }

    /// The completion key associated with the file handle.
    @inlinable
    public var completionKey: UInt {
        UInt(raw.lpCompletionKey)
    }
}

#endif

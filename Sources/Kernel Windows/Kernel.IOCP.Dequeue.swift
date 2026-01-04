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
        /// Dequeue operations.
        public enum Dequeue {

        }
    }

    // MARK: - Operations

    extension Kernel.IOCP.Dequeue {
        /// Dequeues a single completion packet.
        ///
        /// - Parameters:
        ///   - port: The IOCP handle.
        ///   - timeout: Timeout in milliseconds (`INFINITE` = 0xFFFFFFFF).
        /// - Returns: Tuple of (bytes transferred, completion key, overlapped pointer).
        /// - Throws: `Error.timeout` on timeout, `Error.dequeue` on failure.
        @inlinable
        public static func single(
            _ port: Kernel.Descriptor,
            timeout: DWORD
        ) throws(Kernel.IOCP.Error) -> (bytesTransferred: DWORD, completionKey: Kernel.IOCP.CompletionKey, overlapped: LPOVERLAPPED?) {
            var bytes: DWORD = 0
            var key: ULONG_PTR = 0
            var overlapped: LPOVERLAPPED? = nil

            let result = GetQueuedCompletionStatus(
                port.rawValue,
                &bytes,
                &key,
                &overlapped,
                timeout
            )

            if !result {
                let error = GetLastError()
                if error == WAIT_TIMEOUT {
                    throw .timeout
                }
                throw .dequeue(.win32(UInt32(error)))
            }

            return (bytes, Kernel.IOCP.CompletionKey(rawValue: key), overlapped)
        }

        /// Dequeues multiple completion packets (batch).
        ///
        /// More efficient than calling `single` in a loop when multiple
        /// completions are expected.
        ///
        /// - Parameters:
        ///   - port: The IOCP handle.
        ///   - entries: Buffer for completion entries.
        ///   - timeout: Timeout in milliseconds.
        /// - Returns: Number of entries dequeued (0 on timeout).
        /// - Throws: `Error.dequeue` on failure.
        @inlinable
        public static func batch(
            _ port: Kernel.Descriptor,
            entries: UnsafeMutableBufferPointer<OVERLAPPED_ENTRY>,
            timeout: DWORD
        ) throws(Kernel.IOCP.Error) -> Int {
            guard let baseAddress = entries.baseAddress else { return 0 }

            var removed: ULONG = 0
            let result = GetQueuedCompletionStatusEx(
                port.rawValue,
                baseAddress,
                ULONG(entries.count),
                &removed,
                timeout,
                false  // Not alertable
            )

            if !result {
                let error = GetLastError()
                if error == WAIT_TIMEOUT {
                    return 0
                }
                throw .dequeue(.win32(UInt32(error)))
            }

            return Int(removed)
        }
    }

#endif

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

    extension Kernel {
        /// Raw IOCP (I/O Completion Ports) wrappers (Windows only).
        ///
        /// IOCP is the high-performance asynchronous I/O interface for Windows.
        /// This namespace provides policy-free syscall wrappers.
        ///
        /// Higher layers (swift-io) build registration management,
        /// handle tracking, and event dispatch on top of these primitives.
        public enum IOCP {}
    }

    // MARK: - Error Type

    extension Kernel.IOCP {
        /// Errors from IOCP operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create IOCP.
            case createFailed(win32: DWORD)

            /// Failed to associate handle with IOCP.
            case associateFailed(win32: DWORD)

            /// Failed to dequeue completions.
            case dequeueFailed(win32: DWORD)

            /// Failed to post completion.
            case postFailed(win32: DWORD)

            /// Poll timed out.
            case timeout
        }
    }

    extension Kernel.IOCP.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .createFailed(let code):
                return "CreateIoCompletionPort failed (error: \(code))"
            case .associateFailed(let code):
                return "associate failed (error: \(code))"
            case .dequeueFailed(let code):
                return "GetQueuedCompletionStatus failed (error: \(code))"
            case .postFailed(let code):
                return "PostQueuedCompletionStatus failed (error: \(code))"
            case .timeout:
                return "operation timed out"
            }
        }
    }

    extension Kernel.IOCP.Error {
        /// Converts this IOCP error to a `Kernel.Error`.
        public var asKernelError: Kernel.Error {
            switch self {
            case .createFailed(let code):
                return .platform(code: Int32(code), message: "CreateIoCompletionPort failed")
            case .associateFailed(let code):
                return .platform(code: Int32(code), message: "associate failed")
            case .dequeueFailed(let code):
                return .platform(code: Int32(code), message: "GetQueuedCompletionStatus failed")
            case .postFailed(let code):
                return .platform(code: Int32(code), message: "PostQueuedCompletionStatus failed")
            case .timeout:
                return .resource(.blocked)
            }
        }
    }

    // MARK: - Completion Key

    extension Kernel.IOCP {
        /// Completion key for identifying handles.
        ///
        /// The completion key is an application-defined value associated with
        /// a file handle when it's registered with an IOCP.
        public struct CompletionKey: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: ULONG_PTR

            @inlinable
            public init(rawValue: ULONG_PTR) {
                self.rawValue = rawValue
            }
        }
    }

    // MARK: - Syscalls

    extension Kernel.IOCP {
        /// Creates a new I/O completion port.
        ///
        /// - Parameter concurrentThreads: Maximum number of threads allowed to
        ///   concurrently process completions. Pass 0 to use the number of CPUs.
        /// - Returns: The IOCP handle.
        /// - Throws: `Error.createFailed` if creation fails.
        @inlinable
        public static func create(
            concurrentThreads: UInt32 = 0
        ) throws(Error) -> Kernel.Descriptor {
            let handle = CreateIoCompletionPort(
                INVALID_HANDLE_VALUE,
                nil,
                0,
                DWORD(concurrentThreads)
            )
            guard let handle, handle != INVALID_HANDLE_VALUE else {
                throw .createFailed(win32: GetLastError())
            }
            return Kernel.Descriptor(rawValue: handle)
        }

        /// Associates a file handle with the completion port.
        ///
        /// The file handle must have been opened with `FILE_FLAG_OVERLAPPED`.
        ///
        /// - Parameters:
        ///   - port: The IOCP handle.
        ///   - fileHandle: The file handle to associate.
        ///   - completionKey: Application-defined value returned with completions.
        /// - Throws: `Error.associateFailed` if association fails.
        @inlinable
        public static func associate(
            _ port: Kernel.Descriptor,
            fileHandle: HANDLE,
            completionKey: CompletionKey
        ) throws(Error) {
            let result = CreateIoCompletionPort(
                fileHandle,
                port.rawValue,
                completionKey.rawValue,
                0
            )
            guard result != nil else {
                throw .associateFailed(win32: GetLastError())
            }
        }

        /// Dequeues a single completion packet.
        ///
        /// - Parameters:
        ///   - port: The IOCP handle.
        ///   - timeout: Timeout in milliseconds (`INFINITE` = 0xFFFFFFFF).
        /// - Returns: Tuple of (bytes transferred, completion key, overlapped pointer).
        /// - Throws: `Error.timeout` on timeout, `Error.dequeueFailed` on failure.
        @inlinable
        public static func dequeue(
            _ port: Kernel.Descriptor,
            timeout: DWORD
        ) throws(Error) -> (bytesTransferred: DWORD, completionKey: CompletionKey, overlapped: LPOVERLAPPED?) {
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
                throw .dequeueFailed(win32: error)
            }

            return (bytes, CompletionKey(rawValue: key), overlapped)
        }

        /// Dequeues multiple completion packets (batch).
        ///
        /// More efficient than calling `dequeue` in a loop when multiple
        /// completions are expected.
        ///
        /// - Parameters:
        ///   - port: The IOCP handle.
        ///   - entries: Buffer for completion entries.
        ///   - timeout: Timeout in milliseconds.
        /// - Returns: Number of entries dequeued (0 on timeout).
        /// - Throws: `Error.dequeueFailed` on failure.
        @inlinable
        public static func dequeueBatch(
            _ port: Kernel.Descriptor,
            entries: UnsafeMutableBufferPointer<OVERLAPPED_ENTRY>,
            timeout: DWORD
        ) throws(Error) -> Int {
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
                throw .dequeueFailed(win32: error)
            }

            return Int(removed)
        }

        /// Posts a completion packet to the port.
        ///
        /// This can be used to wake up a thread waiting on the port,
        /// or to manually signal completion of an operation.
        ///
        /// - Parameters:
        ///   - port: The IOCP handle.
        ///   - bytesTransferred: Number of bytes to report.
        ///   - completionKey: The completion key to return.
        ///   - overlapped: The overlapped pointer to return (can be nil).
        /// - Throws: `Error.postFailed` on failure.
        @inlinable
        public static func post(
            _ port: Kernel.Descriptor,
            bytesTransferred: DWORD = 0,
            completionKey: CompletionKey = CompletionKey(rawValue: 0),
            overlapped: LPOVERLAPPED? = nil
        ) throws(Error) {
            let result = PostQueuedCompletionStatus(
                port.rawValue,
                bytesTransferred,
                completionKey.rawValue,
                overlapped
            )
            guard result else {
                throw .postFailed(win32: GetLastError())
            }
        }

        /// Cancels pending I/O on a handle.
        ///
        /// Returns silently if the operation already completed (`ERROR_NOT_FOUND`).
        ///
        /// - Parameters:
        ///   - fileHandle: The file handle with pending I/O.
        ///   - overlapped: The overlapped structure for the operation to cancel.
        @inlinable
        public static func cancel(
            fileHandle: HANDLE,
            overlapped: LPOVERLAPPED
        ) {
            _ = CancelIoEx(fileHandle, overlapped)
            // Ignore errors - if not found, already completed
        }

        /// Closes the completion port.
        ///
        /// Uses `Kernel.Close.close()` for consistency. Ignores errors.
        ///
        /// - Parameter port: The IOCP handle to close.
        @inlinable
        public static func close(_ port: Kernel.Descriptor) {
            try? Kernel.Close.close(port)
        }
    }

#endif

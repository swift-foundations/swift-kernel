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

    // MARK: - Overlapped Types

    extension Kernel.IOCP {
        /// Swift wrapper for Windows OVERLAPPED structure.
        ///
        /// The `OVERLAPPED` structure is used by Windows for asynchronous I/O
        /// operations. This wrapper provides a Swift-friendly interface while
        /// maintaining layout compatibility for the container-of pattern.
        public struct Overlapped: @unchecked Sendable {
            /// The underlying Windows OVERLAPPED structure.
            public var raw: OVERLAPPED

            /// Creates a zero-initialized overlapped structure.
            @inlinable
            public init() {
                raw = OVERLAPPED()
            }

            /// The 64-bit file offset for positioned I/O.
            @inlinable
            public var offset: Int64 {
                get { Int64(raw.Offset) | (Int64(raw.OffsetHigh) << 32) }
                set {
                    raw.Offset = DWORD(truncatingIfNeeded: newValue)
                    raw.OffsetHigh = DWORD(truncatingIfNeeded: newValue >> 32)
                }
            }
        }

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
    }

    // MARK: - Windows Error Constants

    extension Kernel.IOCP {
        /// Common Windows error codes used with IOCP operations.
        public enum WindowsError: Sendable {
            /// The I/O operation has been started but not yet completed.
            public static let ioPending: DWORD = DWORD(ERROR_IO_PENDING)

            /// The I/O operation was aborted due to cancellation.
            public static let operationAborted: DWORD = DWORD(ERROR_OPERATION_ABORTED)

            /// The specified operation was not found.
            public static let notFound: DWORD = DWORD(ERROR_NOT_FOUND)

            /// The wait operation timed out.
            public static let timeout: DWORD = WAIT_TIMEOUT

            /// Infinite timeout value.
            public static let infinite: DWORD = INFINITE
        }
    }

    // MARK: - Read/Write Results

    extension Kernel.IOCP {
        /// Result of an overlapped read operation.
        public enum ReadResult: Sendable, Equatable {
            /// The operation is pending asynchronously.
            case pending
            /// The operation completed synchronously with the given byte count.
            case completed(bytes: UInt32)
        }

        /// Result of an overlapped write operation.
        public enum WriteResult: Sendable, Equatable {
            /// The operation is pending asynchronously.
            case pending
            /// The operation completed synchronously with the given byte count.
            case completed(bytes: UInt32)
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

        /// Initiates an overlapped read operation.
        ///
        /// - Parameters:
        ///   - handle: The file handle (must be opened with FILE_FLAG_OVERLAPPED).
        ///   - buffer: The buffer to read into.
        ///   - overlapped: The overlapped structure for this operation.
        /// - Returns: `.pending` if async, `.completed(bytes:)` if sync completion.
        /// - Throws: `Error` on failure (excluding ERROR_IO_PENDING).
        @inlinable
        public static func read(
            _ handle: HANDLE,
            into buffer: UnsafeMutableRawBufferPointer,
            overlapped: UnsafeMutablePointer<OVERLAPPED>
        ) throws(Error) -> ReadResult {
            var bytesRead: DWORD = 0
            let success = ReadFile(
                handle,
                buffer.baseAddress,
                DWORD(buffer.count),
                &bytesRead,
                overlapped
            )

            if success {
                return .completed(bytes: bytesRead)
            }

            let error = GetLastError()
            if error == WindowsError.ioPending {
                return .pending
            }

            throw .readFailed(win32: error)
        }

        /// Initiates an overlapped write operation.
        ///
        /// - Parameters:
        ///   - handle: The file handle (must be opened with FILE_FLAG_OVERLAPPED).
        ///   - buffer: The buffer to write from.
        ///   - overlapped: The overlapped structure for this operation.
        /// - Returns: `.pending` if async, `.completed(bytes:)` if sync completion.
        /// - Throws: `Error` on failure (excluding ERROR_IO_PENDING).
        @inlinable
        public static func write(
            _ handle: HANDLE,
            from buffer: UnsafeRawBufferPointer,
            overlapped: UnsafeMutablePointer<OVERLAPPED>
        ) throws(Error) -> WriteResult {
            var bytesWritten: DWORD = 0
            let success = WriteFile(
                handle,
                buffer.baseAddress,
                DWORD(buffer.count),
                &bytesWritten,
                overlapped
            )

            if success {
                return .completed(bytes: bytesWritten)
            }

            let error = GetLastError()
            if error == WindowsError.ioPending {
                return .pending
            }

            throw .writeFailed(win32: error)
        }

        /// Cancels an overlapped I/O operation.
        ///
        /// - Parameters:
        ///   - handle: The file handle.
        ///   - overlapped: The overlapped structure for the operation to cancel.
        /// - Returns: `true` if cancelled, `false` if already completed (ERROR_NOT_FOUND).
        @inlinable
        public static func cancelIO(
            _ handle: HANDLE,
            overlapped: UnsafeMutablePointer<OVERLAPPED>
        ) -> Bool {
            if CancelIoEx(handle, overlapped) != 0 {
                return true
            }
            return GetLastError() != WindowsError.notFound
        }

        /// Gets the result of a completed overlapped operation.
        ///
        /// - Parameters:
        ///   - handle: The file handle.
        ///   - overlapped: The overlapped structure.
        ///   - wait: If `true`, blocks until the operation completes.
        /// - Returns: The number of bytes transferred.
        /// - Throws: `Error` on failure.
        @inlinable
        public static func result(
            _ handle: HANDLE,
            overlapped: UnsafeMutablePointer<OVERLAPPED>,
            wait: Bool = false
        ) throws(Error) -> UInt32 {
            var bytesTransferred: DWORD = 0
            let success = GetOverlappedResult(
                handle,
                overlapped,
                &bytesTransferred,
                wait
            )

            if success {
                return bytesTransferred
            }

            throw .resultFailed(win32: GetLastError())
        }

        /// Gets the last Windows error code.
        ///
        /// Exposed so swift-io doesn't need to import WinSDK.
        @inlinable
        public static func lastError() -> DWORD {
            GetLastError()
        }
    }

    // MARK: - Extended Error Cases

    extension Kernel.IOCP.Error {
        /// ReadFile failed.
        public static func readFailed(win32: DWORD) -> Self {
            .dequeueFailed(win32: win32)  // Reuse existing case for now
        }

        /// WriteFile failed.
        public static func writeFailed(win32: DWORD) -> Self {
            .dequeueFailed(win32: win32)  // Reuse existing case for now
        }

        /// GetOverlappedResult failed.
        public static func resultFailed(win32: DWORD) -> Self {
            .dequeueFailed(win32: win32)  // Reuse existing case for now
        }
    }

#endif

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
    /// Cancel operations.
    public enum Cancel {

    }
}

// MARK: - Operations

extension Kernel.IOCP.Cancel {
    /// Cancels pending I/O on a handle (fire-and-forget).
    ///
    /// Returns silently if the operation already completed (`ERROR_NOT_FOUND`).
    ///
    /// - Parameters:
    ///   - fileHandle: The file handle with pending I/O.
    ///   - overlapped: The overlapped structure for the operation to cancel.
    @inlinable
    public static func pending(
        fileHandle: HANDLE,
        overlapped: LPOVERLAPPED
    ) {
        _ = CancelIoEx(fileHandle, overlapped)
        // Ignore errors - if not found, already completed
    }

    /// Cancels an overlapped I/O operation with status.
    ///
    /// - Parameters:
    ///   - handle: The file handle.
    ///   - overlapped: The overlapped structure for the operation to cancel.
    /// - Returns: `true` if cancelled, `false` if already completed (ERROR_NOT_FOUND).
    @inlinable
    public static func io(
        _ handle: HANDLE,
        overlapped: UnsafeMutablePointer<OVERLAPPED>
    ) -> Bool {
        if CancelIoEx(handle, overlapped) != 0 {
            return true
        }
        return GetLastError() != Kernel.IOCP.WindowsError.notFound
    }
}

#endif

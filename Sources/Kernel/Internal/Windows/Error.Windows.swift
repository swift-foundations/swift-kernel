//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

#if os(Windows)
public import WinSDK

extension Kernel.Error {
    /// Creates a `Kernel.Error` from a Windows error code.
    ///
    /// - Parameter code: The Windows error code (typically from `GetLastError()`).
    /// - Returns: The corresponding semantic error case, or `.platform` if unmapped.
    @inlinable
    public static func windows(_ code: DWORD) -> Kernel.Error {
        switch code {
        case DWORD(ERROR_FILE_NOT_FOUND), DWORD(ERROR_PATH_NOT_FOUND):
            return .notFound
        case DWORD(ERROR_ACCESS_DENIED):
            return .permissionDenied
        case DWORD(ERROR_FILE_EXISTS), DWORD(ERROR_ALREADY_EXISTS):
            return .alreadyExists
        case DWORD(ERROR_DIRECTORY):
            return .isDirectory
        case DWORD(ERROR_DIRECTORY_NOT_SUPPORTED):
            return .notDirectory
        case DWORD(ERROR_DIR_NOT_EMPTY):
            return .notEmpty
        case DWORD(ERROR_DISK_FULL):
            return .noSpace
        case DWORD(ERROR_TOO_MANY_OPEN_FILES):
            return .tooManyOpenFiles
        case DWORD(ERROR_INVALID_HANDLE):
            return .invalidDescriptor
        case DWORD(ERROR_BROKEN_PIPE):
            return .brokenPipe
        case DWORD(ERROR_LOCK_VIOLATION):
            // Note: This is lock contention, not resource exhaustion
            // The lock() API returns false on contention instead of throwing
            return .wouldBlock
        case DWORD(ERROR_NOT_ENOUGH_MEMORY), DWORD(ERROR_OUTOFMEMORY):
            return .outOfMemory
        default:
            return .platform(code: Int32(code), message: formatWindowsError(code))
        }
    }

    /// Creates a `Kernel.Error` from the current Windows error.
    @inlinable
    public static func currentWindowsError() -> Kernel.Error {
        return windows(GetLastError())
    }
}

// MARK: - Error Formatting

/// Formats a Windows error code into a human-readable message.
@usableFromInline
internal func formatWindowsError(_ code: DWORD) -> String {
    var buffer: LPWSTR? = nil
    let length = FormatMessageW(
        DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS),
        nil,
        code,
        0,
        withUnsafeMutablePointer(to: &buffer) {
            $0.withMemoryRebound(to: WCHAR.self, capacity: 1) { $0 }
        },
        0,
        nil
    )

    defer {
        if let buffer = buffer {
            LocalFree(buffer)
        }
    }

    guard length > 0, let buffer = buffer else {
        return "Unknown error \(code)"
    }

    // Convert UTF-16 to String, trimming trailing newlines
    return String(decodingCString: buffer, as: UTF16.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Internal Helpers

extension Kernel {
    /// Executes a Windows syscall and throws on error.
    ///
    /// - Parameter body: A closure that returns `false` or a NULL handle on error.
    /// - Returns: The result of the syscall if successful.
    /// - Throws: `Kernel.Error` if the syscall fails.
    @inlinable
    internal static func windowsSyscall(
        _ body: () -> BOOL
    ) throws(Kernel.Error) {
        if body() == false {
            throw Kernel.Error.currentWindowsError()
        }
    }

    /// Executes a Windows syscall that returns a handle.
    ///
    /// - Parameter body: A closure that returns `INVALID_HANDLE_VALUE` on error.
    /// - Returns: The valid handle.
    /// - Throws: `Kernel.Error` if the syscall fails.
    @inlinable
    internal static func windowsSyscallHandle(
        _ body: () -> HANDLE?
    ) throws(Kernel.Error) -> HANDLE {
        guard let result = body(), result != INVALID_HANDLE_VALUE else {
            throw Kernel.Error.currentWindowsError()
        }
        return result
    }

    /// Executes a Windows syscall that returns a DWORD count.
    ///
    /// - Parameters:
    ///   - body: A closure that returns `false` on error.
    ///   - count: A pointer to receive the count.
    /// - Returns: The count as an Int.
    /// - Throws: `Kernel.Error` if the syscall fails.
    @inlinable
    internal static func windowsSyscallWithCount(
        _ body: (UnsafeMutablePointer<DWORD>) -> BOOL
    ) throws(Kernel.Error) -> Int {
        var count: DWORD = 0
        if body(&count) == false {
            throw Kernel.Error.currentWindowsError()
        }
        return Int(count)
    }
}
#endif

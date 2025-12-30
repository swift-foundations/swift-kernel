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
        // Path errors
        case DWORD(ERROR_FILE_NOT_FOUND), DWORD(ERROR_PATH_NOT_FOUND):
            return .path(.notFound)
        case DWORD(ERROR_FILE_EXISTS), DWORD(ERROR_ALREADY_EXISTS):
            return .path(.exists)
        case DWORD(ERROR_DIRECTORY):
            return .path(.isDirectory)
        case DWORD(ERROR_DIRECTORY_NOT_SUPPORTED):
            return .path(.notDirectory)
        case DWORD(ERROR_DIR_NOT_EMPTY):
            return .path(.notEmpty)

        // Descriptor errors
        case DWORD(ERROR_INVALID_HANDLE):
            return .descriptor(.invalid)
        case DWORD(ERROR_TOO_MANY_OPEN_FILES):
            return .descriptor(.limit(.process))

        // I/O errors
        case DWORD(ERROR_BROKEN_PIPE):
            return .io(.broken)

        // Memory errors
        case DWORD(ERROR_NOT_ENOUGH_MEMORY), DWORD(ERROR_OUTOFMEMORY):
            return .memory(.exhausted)

        // Resource errors
        case DWORD(ERROR_ACCESS_DENIED):
            return .resource(.permission(.denied))
        case DWORD(ERROR_DISK_FULL):
            return .resource(.space)
        case DWORD(ERROR_LOCK_VIOLATION), DWORD(ERROR_LOCK_FAILED):
            // Note: Lock contention - the lock() API returns false on contention
            // instead of throwing, so this is only hit in edge cases
            return .resource(.blocked)
        case DWORD(ERROR_SHARING_VIOLATION):
            // File is open by another process with incompatible sharing mode
            return .resource(.blocked)
        case DWORD(ERROR_NOT_SAME_DEVICE):
            // Cross-device operation (e.g., rename across volumes)
            return .path(.crossDevice)

        // Additional disk space error
        case DWORD(ERROR_HANDLE_DISK_FULL):
            return .resource(.space)

        // I/O device errors
        case DWORD(ERROR_IO_DEVICE):
            return .io(.device(.unavailable))

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

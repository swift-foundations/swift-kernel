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

extension Kernel {
    /// Unified error type for all kernel syscalls.
    ///
    /// Maps platform errno (POSIX) and DWORD error codes (Windows) to semantic cases.
    /// All `Kernel.Syscalls.*` functions throw this type.
    ///
    /// ## Design Principles
    /// - **Semantic, not platform-specific**: Cases represent user-actionable conditions.
    /// - **Typed throws**: No `rethrows`, no `any Error`.
    /// - **Escape hatch**: `.platform(code:message:)` for unmapped platform errors.
    /// - **EOF is NOT an error**: `read`/`pread` return 0 on EOF.
    public enum Error: Swift.Error, Sendable, Equatable {
        // MARK: - Resource Errors

        /// The specified path or file does not exist.
        /// - POSIX: `ENOENT`
        /// - Windows: `ERROR_FILE_NOT_FOUND`, `ERROR_PATH_NOT_FOUND`
        case notFound

        /// Permission denied for the requested operation.
        /// - POSIX: `EACCES`, `EPERM`
        /// - Windows: `ERROR_ACCESS_DENIED`
        case permissionDenied

        /// A file or directory already exists at the specified path.
        /// - POSIX: `EEXIST`
        /// - Windows: `ERROR_FILE_EXISTS`, `ERROR_ALREADY_EXISTS`
        case alreadyExists

        /// The path refers to a directory when a file was expected.
        /// - POSIX: `EISDIR`
        /// - Windows: `ERROR_DIRECTORY`
        case isDirectory

        /// The path refers to a file when a directory was expected.
        /// - POSIX: `ENOTDIR`
        /// - Windows: `ERROR_DIRECTORY_NOT_SUPPORTED`
        case notDirectory

        /// The directory is not empty and cannot be removed.
        /// - POSIX: `ENOTEMPTY`
        /// - Windows: `ERROR_DIR_NOT_EMPTY`
        case notEmpty

        /// No space left on the device.
        /// - POSIX: `ENOSPC`
        /// - Windows: `ERROR_DISK_FULL`
        case noSpace

        /// Too many open files (process or system limit reached).
        /// - POSIX: `EMFILE`, `ENFILE`
        /// - Windows: `ERROR_TOO_MANY_OPEN_FILES`
        case tooManyOpenFiles

        /// The file descriptor or handle is invalid.
        /// - POSIX: `EBADF`
        /// - Windows: `ERROR_INVALID_HANDLE`
        case invalidDescriptor

        /// The operation was interrupted by a signal.
        /// - POSIX: `EINTR`
        ///
        /// - Note: Kernel does NOT retry on EINTR. Higher layers decide retry policy.
        case interrupted

        /// The operation would block on a non-blocking descriptor.
        /// - POSIX: `EAGAIN`, `EWOULDBLOCK`
        case wouldBlock

        // MARK: - I/O Errors
        // Note: EOF is NOT an error. read/pread return 0 on EOF.

        /// The pipe or socket peer has closed the connection.
        /// - POSIX: `EPIPE`
        /// - Windows: `ERROR_BROKEN_PIPE`
        case brokenPipe

        /// The connection was reset by the remote peer.
        /// - POSIX: `ECONNRESET`
        case connectionReset

        // MARK: - Locking Errors

        /// A deadlock condition was detected.
        /// - POSIX: `EDEADLK`
        case deadlock

        /// No record locks available (system lock table full).
        /// - POSIX: `ENOLCK`
        ///
        /// - Note: This is resource exhaustion, not "lock held by someone else".
        case noLocksAvailable

        // MARK: - Memory Errors

        /// An invalid memory address was provided.
        /// - POSIX: `EFAULT`
        case invalidAddress

        /// Not enough memory available.
        /// - POSIX: `ENOMEM`
        /// - Windows: `ERROR_NOT_ENOUGH_MEMORY`
        case outOfMemory

        // MARK: - Catch-all

        /// A platform-specific error code that is not mapped to a semantic case.
        ///
        /// - Parameters:
        ///   - code: The raw error code (errno on POSIX, GetLastError() on Windows).
        ///   - message: A human-readable description of the error.
        case platform(code: Int32, message: String)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound:
            return "not found"
        case .permissionDenied:
            return "permission denied"
        case .alreadyExists:
            return "already exists"
        case .isDirectory:
            return "is a directory"
        case .notDirectory:
            return "not a directory"
        case .notEmpty:
            return "directory not empty"
        case .noSpace:
            return "no space left on device"
        case .tooManyOpenFiles:
            return "too many open files"
        case .invalidDescriptor:
            return "invalid descriptor"
        case .interrupted:
            return "interrupted"
        case .wouldBlock:
            return "would block"
        case .brokenPipe:
            return "broken pipe"
        case .connectionReset:
            return "connection reset"
        case .deadlock:
            return "deadlock"
        case .noLocksAvailable:
            return "no locks available"
        case .invalidAddress:
            return "invalid address"
        case .outOfMemory:
            return "out of memory"
        case .platform(let code, let message):
            return "platform error \(code): \(message)"
        }
    }
}

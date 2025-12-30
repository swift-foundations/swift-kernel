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

extension Kernel {
    /// Unified error type for all kernel syscalls.
    ///
    /// Maps platform errno (POSIX) and DWORD error codes (Windows) to semantic cases.
    /// Used by all Kernel syscall operations.
    ///
    /// ## Design Principles
    /// - **Semantic, not platform-specific**: Cases represent user-actionable conditions.
    /// - **Typed throws**: No `rethrows`, no `any Error`.
    /// - **Escape hatch**: `.platform(code:message:)` for unmapped platform errors.
    /// - **EOF is NOT an error**: `read`/`pread` return 0 on EOF.
    public enum Error: Swift.Error, Sendable, Equatable {
        // MARK: - Path Errors

        /// Path-related errors.
        case path(Path)

        // MARK: - Descriptor Errors

        /// File descriptor errors.
        case descriptor(Descriptor)

        // MARK: - I/O Errors
        // Note: EOF is NOT an error. read/pread return 0 on EOF.

        /// I/O operation errors.
        case io(IO)

        // MARK: - Lock Errors

        /// File locking errors.
        case lock(Lock)

        // MARK: - Memory Errors

        /// Memory-related errors.
        case memory(Memory)

        // MARK: - Resource Errors

        /// System resource errors.
        case resource(Resource)

        // MARK: - Catch-all

        /// A platform-specific error code that is not mapped to a semantic case.
        ///
        /// - Parameters:
        ///   - code: The raw error code (errno on POSIX, GetLastError() on Windows).
        ///   - message: A human-readable description of the error.
        case platform(code: Int32, message: String)

        // MARK: - Nested Error Types

        /// Path-related error conditions.
        public enum Path: Sendable, Equatable {
            /// The specified path or file does not exist.
            /// - POSIX: `ENOENT`
            /// - Windows: `ERROR_FILE_NOT_FOUND`, `ERROR_PATH_NOT_FOUND`
            case notFound

            /// A file or directory already exists at the specified path.
            /// - POSIX: `EEXIST`
            /// - Windows: `ERROR_FILE_EXISTS`, `ERROR_ALREADY_EXISTS`
            case exists

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

            /// Cross-device link attempted (e.g., rename across filesystems).
            /// - POSIX: `EXDEV`
            /// - Windows: `ERROR_NOT_SAME_DEVICE`
            case crossDevice
        }

        /// File descriptor error conditions.
        public enum Descriptor: Sendable, Equatable {
            /// The file descriptor or handle is invalid.
            /// - POSIX: `EBADF`
            /// - Windows: `ERROR_INVALID_HANDLE`
            case invalid

            /// Too many open files.
            case limit(Limit)

            /// Limit scope for file descriptor exhaustion.
            public enum Limit: Sendable, Equatable {
                /// Per-process file descriptor limit reached.
                /// - POSIX: `EMFILE`
                /// - Windows: `ERROR_TOO_MANY_OPEN_FILES`
                case process

                /// System-wide file descriptor limit reached.
                /// - POSIX: `ENFILE`
                case system
            }
        }

        /// I/O operation error conditions.
        public enum IO: Sendable, Equatable {
            /// The pipe or socket peer has closed the connection.
            /// - POSIX: `EPIPE`
            /// - Windows: `ERROR_BROKEN_PIPE`
            case broken

            /// The connection was reset by the remote peer.
            /// - POSIX: `ECONNRESET`
            case reset

            /// Device-related errors.
            case device(Device)

            /// Device error types.
            public enum Device: Sendable, Equatable {
                /// The device does not support the requested operation.
                /// - POSIX: `ENODEV`
                case unsupported

                /// The device does not exist or is not configured.
                /// - POSIX: `ENXIO`
                /// - Windows: `ERROR_IO_DEVICE`
                case unavailable
            }

            /// Illegal seek on a non-seekable descriptor (e.g., pipe, socket).
            /// - POSIX: `ESPIPE`
            case seek
        }

        /// File locking error conditions.
        public enum Lock: Sendable, Equatable {
            /// A deadlock condition was detected.
            /// - POSIX: `EDEADLK`
            case deadlock

            /// No record locks available (system lock table full).
            /// - POSIX: `ENOLCK`
            ///
            /// - Note: This is resource exhaustion, not "lock held by someone else".
            case unavailable
        }

        /// Memory error conditions.
        public enum Memory: Sendable, Equatable {
            /// An invalid memory address was provided.
            /// - POSIX: `EFAULT`
            case address

            /// Not enough memory available.
            /// - POSIX: `ENOMEM`
            /// - Windows: `ERROR_NOT_ENOUGH_MEMORY`
            case exhausted
        }

        /// System resource error conditions.
        public enum Resource: Sendable, Equatable {
            /// Permission-related errors.
            case permission(Permission)

            /// Permission error types.
            public enum Permission: Sendable, Equatable {
                /// File or directory permission denied.
                /// - POSIX: `EACCES`
                /// - Windows: `ERROR_ACCESS_DENIED`
                case denied

                /// Operation not permitted (requires privilege).
                /// - POSIX: `EPERM`
                case notPermitted
            }

            /// No space left on the device.
            /// - POSIX: `ENOSPC`
            /// - Windows: `ERROR_DISK_FULL`
            case space

            /// The operation was interrupted by a signal.
            /// - POSIX: `EINTR`
            ///
            /// - Note: Kernel does NOT retry on EINTR. Higher layers decide retry policy.
            case interrupted

            /// The operation would block on a non-blocking descriptor.
            /// - POSIX: `EAGAIN`, `EWOULDBLOCK`
            case blocked

            /// The operation is not supported on this descriptor or filesystem.
            /// - POSIX: `ENOTSUP`, `EOPNOTSUPP`
            case unsupported
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let path):
            return path.description
        case .descriptor(let descriptor):
            return descriptor.description
        case .io(let io):
            return io.description
        case .lock(let lock):
            return lock.description
        case .memory(let memory):
            return memory.description
        case .resource(let resource):
            return resource.description
        case .platform(let code, let message):
            return "platform error \(code): \(message)"
        }
    }
}

extension Kernel.Error.Path: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound: return "not found"
        case .exists: return "already exists"
        case .isDirectory: return "is a directory"
        case .notDirectory: return "not a directory"
        case .notEmpty: return "directory not empty"
        case .crossDevice: return "cross-device link"
        }
    }
}

extension Kernel.Error.Descriptor: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "invalid descriptor"
        case .limit(let limit): return limit.description
        }
    }
}

extension Kernel.Error.Descriptor.Limit: CustomStringConvertible {
    public var description: String {
        switch self {
        case .process: return "too many open files in process"
        case .system: return "too many open files in system"
        }
    }
}

extension Kernel.Error.IO: CustomStringConvertible {
    public var description: String {
        switch self {
        case .broken: return "broken pipe"
        case .reset: return "connection reset"
        case .device(let device): return device.description
        case .seek: return "illegal seek"
        }
    }
}

extension Kernel.Error.IO.Device: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupported: return "operation not supported by device"
        case .unavailable: return "device unavailable"
        }
    }
}

extension Kernel.Error.Lock: CustomStringConvertible {
    public var description: String {
        switch self {
        case .deadlock: return "deadlock"
        case .unavailable: return "no locks available"
        }
    }
}

extension Kernel.Error.Memory: CustomStringConvertible {
    public var description: String {
        switch self {
        case .address: return "invalid address"
        case .exhausted: return "out of memory"
        }
    }
}

extension Kernel.Error.Resource: CustomStringConvertible {
    public var description: String {
        switch self {
        case .permission(let permission): return permission.description
        case .space: return "no space left on device"
        case .interrupted: return "interrupted"
        case .blocked: return "would block"
        case .unsupported: return "operation not supported"
        }
    }
}

extension Kernel.Error.Resource.Permission: CustomStringConvertible {
    public var description: String {
        switch self {
        case .denied: return "permission denied"
        case .notPermitted: return "operation not permitted"
        }
    }
}

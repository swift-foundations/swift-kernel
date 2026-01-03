// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel.File.Clone {
    /// Errors that can occur during clone operations.
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        /// Reflink is not supported on this filesystem.
        ///
        /// Returned by `.reflinkOrFail` when the filesystem doesn't support CoW.
        case notSupported

        /// Source and destination are on different filesystems/volumes.
        ///
        /// Reflink requires both paths to be on the same volume.
        case crossDevice

        /// The source file does not exist.
        case sourceNotFound

        /// The destination already exists.
        ///
        /// Clone operations do not overwrite by default.
        case destinationExists

        /// Permission denied for source or destination.
        case permissionDenied

        /// The source is a directory, not a regular file.
        ///
        /// Use a recursive directory clone for directories.
        case isDirectory

        /// A platform-specific error occurred.
        case platform(code: Int32, operation: Operation)

        /// Operation types for error context.
        public enum Operation: String, Sendable, Equatable {
            case clonefile
            case copyfile
            case ficlone
            case copyFileRange
            case duplicateExtents
            case statfs
            case stat
            case copy
        }

        public var description: String {
            switch self {
            case .notSupported:
                return "Reflink not supported on this filesystem"
            case .crossDevice:
                return "Source and destination are on different devices"
            case .sourceNotFound:
                return "Source file not found"
            case .destinationExists:
                return "Destination already exists"
            case .permissionDenied:
                return "Permission denied"
            case .isDirectory:
                return "Source is a directory"
            case .platform(let code, let operation):
                #if !os(Windows)
                    let message = String(cString: strerror(code))
                    return "Platform error \(code) during \(operation): \(message)"
                #else
                    return "Platform error \(code) during \(operation)"
                #endif
            }
        }
    }
}

// MARK: - Internal Syscall Error

extension Kernel.File.Clone {
    /// Internal syscall-level errors for clone operations.
    public enum SyscallError: Swift.Error, Sendable {
        #if !os(Windows)
            case posix(errno: Int32, operation: Operation)
        #endif

        #if os(Windows)
            case windows(code: UInt32, operation: Operation)
        #endif

        case notSupported(operation: Operation)

        public enum Operation: String, Sendable {
            case clonefile
            case copyfile
            case ficlone
            case copyFileRange
            case duplicateExtents
            case statfs
            case stat
            case copy
        }
    }
}

// MARK: - Error Conversion

extension Kernel.File.Clone.Error.Operation {
    /// Creates a public operation from an internal syscall operation.
    public init(from syscallOp: Kernel.File.Clone.SyscallError.Operation) {
        switch syscallOp {
        case .clonefile: self = .clonefile
        case .copyfile: self = .copyfile
        case .ficlone: self = .ficlone
        case .copyFileRange: self = .copyFileRange
        case .duplicateExtents: self = .duplicateExtents
        case .statfs: self = .statfs
        case .stat: self = .stat
        case .copy: self = .copy
        }
    }
}

extension Kernel.File.Clone.Error {
    /// Creates a public error from a syscall error.
    public init(from syscallError: Kernel.File.Clone.SyscallError) {
        switch syscallError {
        case .notSupported:
            self = .notSupported

        #if !os(Windows)
            case .posix(let errno, let operation):
                switch errno {
                case ENOENT:
                    self = .sourceNotFound
                case EEXIST:
                    self = .destinationExists
                case EACCES, EPERM:
                    self = .permissionDenied
                case EXDEV:
                    self = .crossDevice
                case EISDIR:
                    self = .isDirectory
                case ENOTSUP, EOPNOTSUPP:
                    self = .notSupported
                default:
                    self = .platform(code: errno, operation: Operation(from: operation))
                }
        #endif

        #if os(Windows)
            case .windows(let code, let operation):
                switch code {
                case 2:  // ERROR_FILE_NOT_FOUND
                    self = .sourceNotFound
                case 80:  // ERROR_FILE_EXISTS
                    self = .destinationExists
                case 5:  // ERROR_ACCESS_DENIED
                    self = .permissionDenied
                case 17:  // ERROR_NOT_SAME_DEVICE
                    self = .crossDevice
                default:
                    self = .platform(code: Int32(code), operation: Operation(from: operation))
                }
        #endif
        }
    }
}

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

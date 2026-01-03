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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

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
        case platform(code: Kernel.Error.Code, operation: Operation)

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
                if let message = Kernel.Error.message(for: code) {
                    return "Platform error during \(operation): \(message)"
                }
                return "Platform error \(code) during \(operation)"
            }
        }
    }
}

// MARK: - Syscall Error

extension Kernel.File.Clone.Error {
    /// Raw syscall-level errors for clone operations.
    ///
    /// This type captures the exact errno/win32 error code from syscalls.
    /// It is translated to the semantic `Kernel.File.Clone.Error` at API boundaries.
    package enum Syscall: Swift.Error, Sendable {
        /// Platform syscall failure.
        case platform(code: Kernel.Error.Code, operation: Operation)

        /// Operation not supported.
        case notSupported(operation: Operation)
    }
}

// MARK: - Error Conversion

extension Kernel.File.Clone.Error {
    /// Creates a semantic error from a raw syscall error.
    package init(from syscall: Syscall) {
        switch syscall {
        case .notSupported:
            self = .notSupported

        case .platform(let code, let operation):
            self = Self.fromCode(code, operation: operation)
        }
    }

    /// Maps platform error code to semantic error.
    private static func fromCode(_ code: Kernel.Error.Code, operation: Operation) -> Self {
        switch code {
        case .posix(let errno):
            #if !os(Windows)
            switch errno {
            case ENOENT:
                return .sourceNotFound
            case EEXIST:
                return .destinationExists
            case EACCES, EPERM:
                return .permissionDenied
            case EXDEV:
                return .crossDevice
            case EISDIR:
                return .isDirectory
            case ENOTSUP, EOPNOTSUPP:
                return .notSupported
            default:
                return .platform(code: code, operation: operation)
            }
            #else
            return .platform(code: code, operation: operation)
            #endif

        case .win32(let error):
            #if os(Windows)
            switch error {
            case 2:  // ERROR_FILE_NOT_FOUND
                return .sourceNotFound
            case 80:  // ERROR_FILE_EXISTS
                return .destinationExists
            case 5:  // ERROR_ACCESS_DENIED
                return .permissionDenied
            case 17:  // ERROR_NOT_SAME_DEVICE
                return .crossDevice
            default:
                return .platform(code: code, operation: operation)
            }
            #else
            return .platform(code: code, operation: operation)
            #endif
        }
    }
}

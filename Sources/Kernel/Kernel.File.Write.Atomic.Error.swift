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

public import Kernel_Primitives

extension Kernel.File.Write.Atomic {
    /// Errors that can occur during atomic write operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parentVerificationFailed(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Stat on destination file failed.
        case destinationStatFailed(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Temp file creation failed.
        case tempFileCreationFailed(directory: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Write operation failed.
        case writeFailed(bytesWritten: Int, bytesExpected: Int, code: Kernel.Error.Code, message: Swift.String)

        /// File sync (fsync/flush) failed.
        case syncFailed(code: Kernel.Error.Code, message: Swift.String)

        /// File close failed.
        case closeFailed(code: Kernel.Error.Code, message: Swift.String)

        /// Metadata preservation failed.
        case metadataPreservationFailed(operation: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Timestamp preservation failed.
        case timestampPreservationFailed(Kernel.File.Times.Error)

        /// Atomic rename failed.
        case renameFailed(from: Swift.String, to: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Destination already exists (noClobber mode).
        case destinationExists(path: Swift.String)

        /// Directory sync failed (before commit completed).
        case directorySyncFailed(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation. The caller should NOT attempt
        /// to "finish durability" - this is not reliably possible.
        case directorySyncFailedAfterCommit(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// CSPRNG failed - cannot generate secure temp file names.
        ///
        /// This indicates a fundamental system failure (e.g., getrandom syscall failure).
        /// The operation cannot proceed safely without secure random bytes.
        case randomGenerationFailed(code: Kernel.Error.Code, operation: Swift.String, message: Swift.String)

        /// Platform layout incompatibility at runtime.
        ///
        /// This occurs when platform-specific struct layouts don't match expectations.
        /// Typically indicates a need for fallback to alternative APIs.
        case platformIncompatible(operation: Swift.String, message: Swift.String)
    }
}

// MARK: - Semantic Accessors

extension Kernel.File.Write.Atomic.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        #if os(Windows)
        switch self {
        case .parentVerificationFailed(_, let code, _):
            return code == .Windows.ERROR_FILE_NOT_FOUND || code == .Windows.ERROR_PATH_NOT_FOUND
        case .destinationStatFailed(_, let code, _):
            return code == .Windows.ERROR_FILE_NOT_FOUND || code == .Windows.ERROR_PATH_NOT_FOUND
        case .tempFileCreationFailed(_, let code, _):
            return code == .Windows.ERROR_FILE_NOT_FOUND || code == .Windows.ERROR_PATH_NOT_FOUND
        default:
            return false
        }
        #else
        switch self {
        case .parentVerificationFailed(_, let code, _):
            return code == .POSIX.ENOENT
        case .destinationStatFailed(_, let code, _):
            return code == .POSIX.ENOENT
        case .tempFileCreationFailed(_, let code, _):
            return code == .POSIX.ENOENT
        default:
            return false
        }
        #endif
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        #if os(Windows)
        switch self {
        case .parentVerificationFailed(_, let code, _),
             .destinationStatFailed(_, let code, _),
             .tempFileCreationFailed(_, let code, _),
             .writeFailed(_, _, let code, _),
             .syncFailed(let code, _),
             .closeFailed(let code, _),
             .metadataPreservationFailed(_, let code, _),
             .renameFailed(_, _, let code, _),
             .directorySyncFailed(_, let code, _),
             .directorySyncFailedAfterCommit(_, let code, _):
            return code == .Windows.ERROR_ACCESS_DENIED
        case .randomGenerationFailed(let code, _, _):
            return code == .Windows.ERROR_ACCESS_DENIED
        default:
            return false
        }
        #else
        switch self {
        case .parentVerificationFailed(_, let code, _),
             .destinationStatFailed(_, let code, _),
             .tempFileCreationFailed(_, let code, _),
             .writeFailed(_, _, let code, _),
             .syncFailed(let code, _),
             .closeFailed(let code, _),
             .metadataPreservationFailed(_, let code, _),
             .renameFailed(_, _, let code, _),
             .directorySyncFailed(_, let code, _),
             .directorySyncFailedAfterCommit(_, let code, _):
            return code == .POSIX.EACCES || code == .POSIX.EPERM
        case .randomGenerationFailed(let code, _, _):
            return code == .POSIX.EACCES || code == .POSIX.EPERM
        default:
            return false
        }
        #endif
    }

    /// Returns `true` if the destination already exists (noClobber mode).
    public var isDestinationExists: Bool {
        if case .destinationExists = self { return true }
        return false
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        #if os(Windows)
        switch self {
        case .tempFileCreationFailed(_, let code, _),
             .writeFailed(_, _, let code, _),
             .syncFailed(let code, _),
             .renameFailed(_, _, let code, _),
             .directorySyncFailed(_, let code, _),
             .directorySyncFailedAfterCommit(_, let code, _):
            return code == .Windows.ERROR_WRITE_PROTECT
        default:
            return false
        }
        #else
        switch self {
        case .tempFileCreationFailed(_, let code, _),
             .writeFailed(_, _, let code, _),
             .syncFailed(let code, _),
             .renameFailed(_, _, let code, _),
             .directorySyncFailed(_, let code, _),
             .directorySyncFailedAfterCommit(_, let code, _):
            return code == .POSIX.EROFS
        default:
            return false
        }
        #endif
    }

    /// Returns `true` if there is no space left on device.
    public var isNoSpace: Bool {
        #if os(Windows)
        switch self {
        case .tempFileCreationFailed(_, let code, _),
             .writeFailed(_, _, let code, _),
             .syncFailed(let code, _):
            return code == .Windows.ERROR_DISK_FULL
        default:
            return false
        }
        #else
        switch self {
        case .tempFileCreationFailed(_, let code, _),
             .writeFailed(_, _, let code, _),
             .syncFailed(let code, _):
            return code == .POSIX.ENOSPC
        default:
            return false
        }
        #endif
    }

    /// Returns `true` if durability was compromised after successful rename.
    public var isDurabilityCompromised: Bool {
        if case .directorySyncFailedAfterCommit = self { return true }
        return false
    }

    /// Returns `true` if the platform is incompatible.
    public var isPlatformIncompatible: Bool {
        if case .platformIncompatible = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.Write.Atomic.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .parentVerificationFailed(let path, let code, let message):
            return "Parent directory error '\(path)': \(message) (\(code))"
        case .destinationStatFailed(let path, let code, let message):
            return "Failed to stat destination '\(path)': \(message) (\(code))"
        case .tempFileCreationFailed(let directory, let code, let message):
            return "Failed to create temp file in '\(directory)': \(message) (\(code))"
        case .writeFailed(let written, let expected, let code, let message):
            return "Write failed after \(written)/\(expected) bytes: \(message) (\(code))"
        case .syncFailed(let code, let message):
            return "Sync failed: \(message) (\(code))"
        case .closeFailed(let code, let message):
            return "Close failed: \(message) (\(code))"
        case .metadataPreservationFailed(let op, let code, let message):
            return "Metadata preservation failed (\(op)): \(message) (\(code))"
        case .timestampPreservationFailed(let error):
            return "Timestamp preservation failed (futimens): \(error)"
        case .renameFailed(let from, let to, let code, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (\(code))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let code, let message):
            return "Directory sync failed '\(path)': \(message) (\(code))"
        case .directorySyncFailedAfterCommit(let path, let code, let message):
            return "Directory sync failed after commit '\(path)': \(message) (\(code))"
        case .randomGenerationFailed(let code, let operation, let message):
            return "Random generation failed (\(operation)): \(message) (\(code))"
        case .platformIncompatible(let operation, let message):
            return "Platform incompatible (\(operation)): \(message)"
        }
    }
}

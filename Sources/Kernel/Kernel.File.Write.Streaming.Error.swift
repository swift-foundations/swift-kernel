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

extension Kernel.File.Write.Streaming {
    /// Errors that can occur during streaming write operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parentVerificationFailed(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// File creation failed.
        case fileCreationFailed(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Write operation failed.
        case writeFailed(path: Swift.String, bytesWritten: Int, code: Kernel.Error.Code, message: Swift.String)

        /// File sync (fsync/flush) failed.
        case syncFailed(code: Kernel.Error.Code, message: Swift.String)

        /// File close failed.
        case closeFailed(code: Kernel.Error.Code, message: Swift.String)

        /// Atomic rename failed.
        case renameFailed(from: Swift.String, to: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Destination already exists (noClobber mode).
        case destinationExists(path: Swift.String)

        /// Directory sync failed (before commit completed).
        case directorySyncFailed(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// Write completed but durability guarantee not met due to cancellation.
        ///
        /// File data was flushed (fsync succeeded), but directory entry may not be persisted.
        /// The destination path exists and contains complete content.
        ///
        /// **Callers should NOT attempt to "finish durability"** - this is not reliably possible.
        case durabilityNotGuaranteed(path: Swift.String, reason: Swift.String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation.
        case directorySyncFailedAfterCommit(path: Swift.String, code: Kernel.Error.Code, message: Swift.String)

        /// The streaming write is not in a valid state for this operation.
        ///
        /// This occurs when trying to write to a closed or committed stream.
        case invalidState

        /// Random token generation failed.
        ///
        /// This is an extremely rare error indicating the kernel CSPRNG failed.
        case randomGenerationFailed(code: Kernel.Error.Code, message: Swift.String)

        /// The user-provided fill closure threw an error.
        ///
        /// Used by the reusable-buffer streaming API when the fill closure fails.
        /// The underlying error's description is preserved in the message.
        case userError(message: Swift.String)

        /// The fill closure returned more bytes than the buffer capacity.
        ///
        /// This indicates a programming error in the fill closure.
        case invalidFillResult(produced: Int, capacity: Int)
    }
}

// MARK: - Semantic Accessors

extension Kernel.File.Write.Streaming.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        #if os(Windows)
        switch self {
        case .parentVerificationFailed(_, let code, _):
            return code == .Windows.ERROR_FILE_NOT_FOUND || code == .Windows.ERROR_PATH_NOT_FOUND
        case .fileCreationFailed(_, let code, _):
            return code == .Windows.ERROR_FILE_NOT_FOUND || code == .Windows.ERROR_PATH_NOT_FOUND
        default:
            return false
        }
        #else
        switch self {
        case .parentVerificationFailed(_, let code, _):
            return code == .POSIX.ENOENT
        case .fileCreationFailed(_, let code, _):
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
        case .parentVerificationFailed(_, let code, _):
            return code == .Windows.ERROR_ACCESS_DENIED
        case .fileCreationFailed(_, let code, _):
            return code == .Windows.ERROR_ACCESS_DENIED
        default:
            return false
        }
        #else
        switch self {
        case .parentVerificationFailed(_, let code, _):
            return code == .POSIX.EACCES || code == .POSIX.EPERM
        case .fileCreationFailed(_, let code, _):
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
        case .fileCreationFailed(_, let code, _):
            return code == .Windows.ERROR_WRITE_PROTECT
        case .writeFailed(_, _, let code, _):
            return code == .Windows.ERROR_WRITE_PROTECT
        default:
            return false
        }
        #else
        switch self {
        case .fileCreationFailed(_, let code, _):
            return code == .POSIX.EROFS
        case .writeFailed(_, _, let code, _):
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
        case .writeFailed(_, _, let code, _):
            return code == .Windows.ERROR_DISK_FULL
        case .syncFailed(let code, _):
            return code == .Windows.ERROR_DISK_FULL
        default:
            return false
        }
        #else
        switch self {
        case .writeFailed(_, _, let code, _):
            return code == .POSIX.ENOSPC
        case .syncFailed(let code, _):
            return code == .POSIX.ENOSPC
        default:
            return false
        }
        #endif
    }

    /// Returns `true` if this is a user error from the fill closure.
    public var isUserError: Bool {
        if case .userError = self { return true }
        return false
    }

    /// Returns `true` if durability was not guaranteed.
    public var isDurabilityNotGuaranteed: Bool {
        if case .durabilityNotGuaranteed = self { return true }
        if case .directorySyncFailedAfterCommit = self { return true }
        return false
    }

    /// Returns `true` if the streaming write is in an invalid state.
    public var isInvalidState: Bool {
        if case .invalidState = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.Write.Streaming.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .parentVerificationFailed(let path, let code, let message):
            return "Parent directory error '\(path)': \(message) (\(code))"
        case .fileCreationFailed(let path, let code, let message):
            return "Failed to create file '\(path)': \(message) (\(code))"
        case .writeFailed(let path, let written, let code, let message):
            return "Write failed to '\(path)' after \(written) bytes: \(message) (\(code))"
        case .syncFailed(let code, let message):
            return "Sync failed: \(message) (\(code))"
        case .closeFailed(let code, let message):
            return "Close failed: \(message) (\(code))"
        case .renameFailed(let from, let to, let code, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (\(code))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let code, let message):
            return "Directory sync failed '\(path)': \(message) (\(code))"
        case .durabilityNotGuaranteed(let path, let reason):
            return "Write to '\(path)' completed but durability not guaranteed: \(reason)"
        case .directorySyncFailedAfterCommit(let path, let code, let message):
            return "Directory sync failed after commit '\(path)': \(message) (\(code))"
        case .invalidState:
            return "Streaming write is not in a valid state for this operation"
        case .randomGenerationFailed(let code, let message):
            return "Random token generation failed: \(message) (\(code))"
        case .userError(let message):
            return "User-provided closure failed: \(message)"
        case .invalidFillResult(let produced, let capacity):
            return "Fill closure returned \(produced) bytes but buffer capacity is \(capacity)"
        }
    }
}

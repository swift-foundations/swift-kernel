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

// MARK: - Error Mapping
//
// Extension initializers that map platform error codes to domain errors.
// Each domain error type has init?(errno:) for POSIX and init?(windowsError:) for Windows.

#if !os(Windows)
public import SystemPackage

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// MARK: - Path Resolution

extension Kernel.Path.Resolution.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .noSuchFileOrDirectory: self = .notFound
        case .fileExists: self = .exists
        case .isDirectory: self = .isDirectory
        case .notDirectory: self = .notDirectory
        case .directoryNotEmpty: self = .notEmpty
        case .tooManySymbolicLinkLevels: self = .loop
        case .improperLink: self = .crossDevice
        case .fileNameTooLong: self = .nameTooLong
        default: return nil
        }
    }
}

// MARK: - Permission

extension Kernel.Permission.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .permissionDenied: self = .denied
        case .notPermitted: self = .notPermitted
        case .readOnlyFileSystem: self = .readOnlyFilesystem
        default: return nil
        }
    }
}

// MARK: - Handle

extension Kernel.Descriptor.Validity.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .badFileDescriptor: self = .invalid
        case .tooManyOpenFiles: self = .limit(.process)
        case .tooManyOpenFilesInSystem: self = .limit(.system)
        default: return nil
        }
    }
}

// MARK: - Signal

extension Kernel.Signal.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .interrupted: self = .interrupted
        default: return nil
        }
    }
}

// MARK: - Blocking

extension Kernel.IO.Blocking.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .wouldBlock, .resourceTemporarilyUnavailable: self = .wouldBlock
        default: return nil
        }
    }
}

// MARK: - Space

extension Kernel.Storage.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .noSpace: self = .exhausted
        case .diskQuotaExceeded: self = .quota
        default: return nil
        }
    }
}

// MARK: - Memory

extension Kernel.Memory.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .badAddress: self = .fault
        case .noMemory: self = .exhausted
        default: return nil
        }
    }
}

// MARK: - IO

extension Kernel.IO.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .ioError: self = .hardware
        case .brokenPipe: self = .broken
        case .connectionReset: self = .reset
        case .illegalSeek: self = .illegalSeek
        case .notSupported: self = .unsupported
        default: return nil
        }
    }
}

// MARK: - Lock

extension Kernel.Lock.Error {
    @inlinable
    public init?(errno: Errno) {
        switch errno {
        case .noLocks: self = .unavailable
        case .deadlock: self = .deadlock
        default: return nil
        }
    }
}

// MARK: - Platform (catch-all)

extension Kernel.Errno.Unmapped.Error {
    /// Creates a platform error from an errno value.
    @inlinable
    public init(errno: Errno) {
        self = .unmapped(code: .posix(errno.rawValue), message: nil)
    }
}

#endif

// MARK: - Windows Error Mapping

#if os(Windows)
public import WinSDK

extension Kernel.Path.Resolution.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND: self = .notFound
        case ERROR_FILE_EXISTS, ERROR_ALREADY_EXISTS: self = .exists
        case ERROR_DIRECTORY: self = .isDirectory
        case ERROR_DIRECTORY_NOT_SUPPORTED: self = .notDirectory
        case ERROR_DIR_NOT_EMPTY: self = .notEmpty
        case ERROR_NOT_SAME_DEVICE: self = .crossDevice
        default: return nil
        }
    }
}

extension Kernel.Permission.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_ACCESS_DENIED: self = .denied
        default: return nil
        }
    }
}

extension Kernel.Descriptor.Validity.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_INVALID_HANDLE: self = .invalid
        case ERROR_TOO_MANY_OPEN_FILES: self = .limit(.process)
        default: return nil
        }
    }
}

extension Kernel.Storage.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_DISK_FULL: self = .exhausted
        default: return nil
        }
    }
}

extension Kernel.Memory.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_NOT_ENOUGH_MEMORY, ERROR_OUTOFMEMORY: self = .exhausted
        default: return nil
        }
    }
}

extension Kernel.IO.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_BROKEN_PIPE: self = .broken
        default: return nil
        }
    }
}

extension Kernel.Lock.Error {
    @inlinable
    public init?(windowsError error: DWORD) {
        switch Int32(error) {
        case ERROR_LOCK_VIOLATION: self = .contention
        default: return nil
        }
    }
}

extension Kernel.Errno.Unmapped.Error {
    /// Creates a platform error from a Windows error code.
    @inlinable
    public init(windowsError error: DWORD) {
        self = .unmapped(code: .win32(UInt32(error)), message: nil)
    }
}

#endif

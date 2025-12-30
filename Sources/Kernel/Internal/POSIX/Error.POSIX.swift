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

#if !os(Windows)
public import SystemPackage

#if canImport(Darwin)
public import Darwin
#elseif canImport(Glibc)
public import Glibc
#elseif canImport(Musl)
public import Musl
#endif

extension Kernel.Error {
    /// Creates a `Kernel.Error` from a swift-system `Errno`.
    ///
    /// Uses swift-system's Errno for portable error handling.
    ///
    /// - Parameter errno: The swift-system Errno value.
    /// - Returns: The corresponding semantic error case, or `.platform` if unmapped.
    @inlinable
    public static func fromErrno(_ errno: Errno) -> Kernel.Error {
        switch errno {
        case .noSuchFileOrDirectory:
            return .notFound
        case .permissionDenied, .notPermitted:
            return .permissionDenied
        case .fileExists:
            return .alreadyExists
        case .isDirectory:
            return .isDirectory
        case .notDirectory:
            return .notDirectory
        case .directoryNotEmpty:
            return .notEmpty
        case .noSpace:
            return .noSpace
        case .tooManyOpenFiles:
            return .tooManyOpenFiles
        case .badFileDescriptor:
            return .invalidDescriptor
        case .interrupted:
            return .interrupted
        case .wouldBlock, .resourceTemporarilyUnavailable:
            return .wouldBlock
        case .brokenPipe:
            return .brokenPipe
        case .connectionReset:
            return .connectionReset
        case .deadlock:
            return .deadlock
        case .noLocks:
            return .noLocksAvailable
        case .badAddress:
            return .invalidAddress
        case .noMemory:
            return .outOfMemory
        default:
            return .platform(code: errno.rawValue, message: String(describing: errno))
        }
    }

    /// Creates a `Kernel.Error` from a POSIX errno value.
    ///
    /// - Parameter errno: The raw POSIX error number.
    /// - Returns: The corresponding semantic error case, or `.platform` if unmapped.
    @inlinable
    public static func posix(_ errno: Int32) -> Kernel.Error {
        return fromErrno(Errno(rawValue: errno))
    }

    /// Creates a `Kernel.Error` from the current errno value.
    @inlinable
    public static func currentPosixError() -> Kernel.Error {
        return fromErrno(Errno(rawValue: errno))
    }
}

// MARK: - Internal Helpers

extension Kernel {
    /// Executes a POSIX syscall and throws on error.
    ///
    /// - Parameter body: A closure that returns -1 on error (standard POSIX convention).
    /// - Returns: The result of the syscall if successful.
    /// - Throws: `Kernel.Error` if the syscall returns -1.
    @inlinable
    internal static func posixSyscall<T: FixedWidthInteger>(
        _ body: () -> T
    ) throws(Kernel.Error) -> T {
        let result = body()
        if result == -1 {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    /// Executes a POSIX syscall that returns a pointer, throwing on NULL.
    ///
    /// - Parameter body: A closure that returns NULL on error.
    /// - Returns: The non-null pointer result.
    /// - Throws: `Kernel.Error` if the syscall returns NULL.
    @inlinable
    internal static func posixSyscallPointer<T>(
        _ body: () -> UnsafeMutablePointer<T>?
    ) throws(Kernel.Error) -> UnsafeMutablePointer<T> {
        guard let result = body() else {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    /// Executes a POSIX syscall that returns a raw pointer, throwing on NULL or MAP_FAILED.
    ///
    /// - Parameter body: A closure that returns NULL or MAP_FAILED on error.
    /// - Returns: The valid pointer result.
    /// - Throws: `Kernel.Error` if the syscall fails.
    @inlinable
    internal static func posixSyscallRawPointer(
        _ body: () -> UnsafeMutableRawPointer?
    ) throws(Kernel.Error) -> UnsafeMutableRawPointer {
        guard let result = body() else {
            throw Kernel.Error.currentPosixError()
        }
        // Check for MAP_FAILED (-1 cast to pointer)
        if result == UnsafeMutableRawPointer(bitPattern: -1) {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }
}
#endif

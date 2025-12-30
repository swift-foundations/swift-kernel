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

public import SystemPackage

// MARK: - Open Error Type

extension Kernel {
    public enum Open: Sendable {
        public enum Error: Swift.Error, Sendable {
            case path(Kernel.Path.Resolution.Error)
            case permission(Kernel.Permission.Error)
            case handle(Kernel.Handle.Error)
            case signal(Kernel.Signal.Error)
            case space(Kernel.Space.Error)
            case io(Kernel.IO.Error)
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Open.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.path(l), .path(r)): return l == r
        case let (.permission(l), .permission(r)): return l == r
        case let (.handle(l), .handle(r)): return l == r
        case let (.signal(l), .signal(r)): return l == r
        case let (.space(l), .space(r)): return l == r
        case let (.io(l), .io(r)): return l == r
        case let (.platform(l), .platform(r)): return l == r
        default: return false
        }
    }
}

extension Kernel.Open.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let e): return "path: \(e)"
        case .permission(let e): return "permission: \(e)"
        case .handle(let e): return "handle: \(e)"
        case .signal(let e): return "signal: \(e)"
        case .space(let e): return "space: \(e)"
        case .io(let e): return "io: \(e)"
        case .platform(let e): return "\(e)"
        }
    }
}

// MARK: - Close Error Type

extension Kernel {
    public enum Close: Sendable {
        public enum Error: Swift.Error, Sendable {
            case handle(Kernel.Handle.Error)
            case signal(Kernel.Signal.Error)
            case io(Kernel.IO.Error)
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Close.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.handle(l), .handle(r)): return l == r
        case let (.signal(l), .signal(r)): return l == r
        case let (.io(l), .io(r)): return l == r
        case let (.platform(l), .platform(r)): return l == r
        default: return false
        }
    }
}

extension Kernel.Close.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
        case .signal(let e): return "signal: \(e)"
        case .io(let e): return "io: \(e)"
        case .platform(let e): return "\(e)"
        }
    }
}

// MARK: - POSIX Implementation

#if !os(Windows)

#if canImport(Darwin)
public import Darwin
#elseif canImport(Glibc)
public import Glibc
#elseif canImport(Musl)
public import Musl
#endif

// MARK: Error Mapping

extension Kernel.Open.Error {
    @inlinable
    init(errno: Errno) {
        if let e = Kernel.Path.Resolution.Error(errno: errno) { self = .path(e); return }
        if let e = Kernel.Permission.Error(errno: errno) { self = .permission(e); return }
        if let e = Kernel.Handle.Error(errno: errno) { self = .handle(e); return }
        if let e = Kernel.Signal.Error(errno: errno) { self = .signal(e); return }
        if let e = Kernel.Space.Error(errno: errno) { self = .space(e); return }
        if let e = Kernel.IO.Error(errno: errno) { self = .io(e); return }
        self = .platform(Kernel.Platform.Error(errno: errno))
    }

    @inlinable
    static func current() -> Self {
        Self(errno: Errno(rawValue: errno))
    }
}

extension Kernel.Close.Error {
    @inlinable
    init(errno: Errno) {
        if let e = Kernel.Handle.Error(errno: errno) { self = .handle(e); return }
        if let e = Kernel.Signal.Error(errno: errno) { self = .signal(e); return }
        if let e = Kernel.IO.Error(errno: errno) { self = .io(e); return }
        self = .platform(Kernel.Platform.Error(errno: errno))
    }

    @inlinable
    static func current() -> Self {
        Self(errno: Errno(rawValue: errno))
    }
}

// MARK: Open Syscall

extension Kernel.Open {
    /// Opens a file at the specified path.
    public static func open(
        path: FilePath,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Error) -> Kernel.Descriptor {
        do {
            return try path.withPlatformString { cString in
                try open(unsafePath: cString, mode: mode, options: options, permissions: permissions)
            }
        } catch let error as Error {
            throw error
        } catch {
            throw .platform(.unmapped(code: -1, message: "Unexpected error: \(error)"))
        }
    }

    /// Opens a file at the specified path.
    @inlinable
    public static func open(
        path: borrowing Kernel.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Error) -> Kernel.Descriptor {
        try open(unsafePath: path.cString, mode: mode, options: options, permissions: permissions)
    }

    /// Opens a file at the specified path.
    @inlinable
    public static func open(
        unsafePath: UnsafePointer<CChar>,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Error) -> Kernel.Descriptor {
        let flags = mode.posixFlags | options.posixFlags

        let fd: Int32
        if options.contains(.create) {
            fd = _cOpen(unsafePath, flags, mode_t(permissions))
        } else {
            fd = _cOpen(unsafePath, flags)
        }

        guard fd >= 0 else {
            throw .current()
        }

        #if canImport(Darwin)
        if options.contains(.cacheDisabled) {
            _ = fcntl(fd, F_NOCACHE, 1)
        }
        #endif

        return fd
    }
}

// MARK: Close Syscall

extension Kernel.Close {
    /// Closes a file descriptor.
    @inlinable
    public static func close(_ descriptor: Kernel.Descriptor) throws(Error) {
        guard descriptor >= 0 else {
            throw .handle(.invalid)
        }
        guard _cClose(descriptor) == 0 else {
            throw .current()
        }
    }
}

#endif

// MARK: - Windows Implementation

#if os(Windows)
public import WinSDK

extension Kernel.Open.Error {
    @inlinable
    init(windowsError error: DWORD) {
        if let e = Kernel.Path.Resolution.Error(windowsError: error) { self = .path(e); return }
        if let e = Kernel.Permission.Error(windowsError: error) { self = .permission(e); return }
        if let e = Kernel.Handle.Error(windowsError: error) { self = .handle(e); return }
        if let e = Kernel.Space.Error(windowsError: error) { self = .space(e); return }
        if let e = Kernel.IO.Error(windowsError: error) { self = .io(e); return }
        self = .platform(Kernel.Platform.Error(windowsError: error))
    }

    @inlinable
    static func current() -> Self {
        Self(windowsError: GetLastError())
    }
}

extension Kernel.Close.Error {
    @inlinable
    init(windowsError error: DWORD) {
        if let e = Kernel.Handle.Error(windowsError: error) { self = .handle(e); return }
        if let e = Kernel.IO.Error(windowsError: error) { self = .io(e); return }
        self = .platform(Kernel.Platform.Error(windowsError: error))
    }

    @inlinable
    static func current() -> Self {
        Self(windowsError: GetLastError())
    }
}

extension Kernel.Open {
    /// Opens a file at the specified path.
    public static func open(
        path: FilePath,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Error) -> Kernel.Descriptor {
        try path.withPlatformString { wpath in
            try open(unsafePath: wpath, mode: mode, options: options, permissions: permissions)
        }
    }

    /// Opens a file at the specified path.
    @inlinable
    public static func open(
        path: borrowing Kernel.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Error) -> Kernel.Descriptor {
        let widePath = String(cString: path.cString)
        return try widePath.withCString(encodedAs: UTF16.self) { wpath in
            try open(unsafePath: wpath, mode: mode, options: options, permissions: permissions)
        }
    }

    /// Opens a file at the specified path (Windows wide string).
    @inlinable
    public static func open(
        unsafePath: UnsafePointer<WCHAR>,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Error) -> Kernel.Descriptor {
        let desiredAccess = mode.windowsDesiredAccess(options: options)
        let creationDisposition = options.windowsCreationDisposition
        let flagsAndAttributes = options.windowsFlagsAndAttributes
        let shareMode = Kernel.File.Open.Options.windowsShareMode

        var securityAttributes = SECURITY_ATTRIBUTES()
        securityAttributes.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
        securityAttributes.lpSecurityDescriptor = nil
        securityAttributes.bInheritHandle = options.contains(.execClose) ? false : true

        let handle = CreateFileW(
            unsafePath,
            desiredAccess,
            shareMode,
            &securityAttributes,
            creationDisposition,
            flagsAndAttributes,
            nil
        )

        guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
            throw .current()
        }

        return handle
    }
}

extension Kernel.Close {
    /// Closes a file handle.
    @inlinable
    public static func close(_ descriptor: Kernel.Descriptor) throws(Error) {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .handle(.invalid)
        }
        if CloseHandle(descriptor) == false {
            throw .current()
        }
    }
}

#endif

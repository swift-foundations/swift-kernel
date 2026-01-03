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

public import SystemPackage

extension Kernel.Write {
    /// Errors that can occur during write operations.
    public enum Error: Swift.Error, Sendable {
        case handle(Kernel.Handle.Error)
        case signal(Kernel.Signal.Error)
        case blocking(Kernel.Blocking.Error)
        case io(Kernel.IO.Error)
        case space(Kernel.Space.Error)
        case memory(Kernel.Memory.Error)
        case platform(Kernel.Platform.Error)
    }
}

// MARK: - Equatable

extension Kernel.Write.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.signal(let l), .signal(let r)): return l == r
        case (.blocking(let l), .blocking(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.space(let l), .space(let r)): return l == r
        case (.memory(let l), .memory(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Write.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
        case .signal(let e): return "signal: \(e)"
        case .blocking(let e): return "blocking: \(e)"
        case .io(let e): return "io: \(e)"
        case .space(let e): return "space: \(e)"
        case .memory(let e): return "memory: \(e)"
        case .platform(let e): return "\(e)"
        }
    }
}

// MARK: - POSIX Initialization

#if !os(Windows)

#if canImport(Darwin)
public import Darwin
#elseif canImport(Glibc)
public import Glibc
#elseif canImport(Musl)
public import Musl
#endif

extension Kernel.Write.Error {
    @inlinable
    init(errno: Errno) {
        if let e = Kernel.Handle.Error(errno: errno) {
            self = .handle(e)
            return
        }
        if let e = Kernel.Signal.Error(errno: errno) {
            self = .signal(e)
            return
        }
        if let e = Kernel.Blocking.Error(errno: errno) {
            self = .blocking(e)
            return
        }
        if let e = Kernel.IO.Error(errno: errno) {
            self = .io(e)
            return
        }
        if let e = Kernel.Space.Error(errno: errno) {
            self = .space(e)
            return
        }
        if let e = Kernel.Memory.Error(errno: errno) {
            self = .memory(e)
            return
        }
        self = .platform(Kernel.Platform.Error(errno: errno))
    }

    @inlinable
    static func current() -> Self {
        Self(errno: Errno(rawValue: errno))
    }
}

#endif

// MARK: - Windows Initialization

#if os(Windows)
public import WinSDK

extension Kernel.Write.Error {
    @inlinable
    init(windowsError error: DWORD) {
        if let e = Kernel.Handle.Error(windowsError: error) {
            self = .handle(e)
            return
        }
        if let e = Kernel.IO.Error(windowsError: error) {
            self = .io(e)
            return
        }
        if let e = Kernel.Space.Error(windowsError: error) {
            self = .space(e)
            return
        }
        self = .platform(Kernel.Platform.Error(windowsError: error))
    }

    @inlinable
    static func current() -> Self {
        Self(windowsError: GetLastError())
    }
}

#endif

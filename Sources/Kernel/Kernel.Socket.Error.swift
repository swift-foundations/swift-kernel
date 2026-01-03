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

extension Kernel.Socket {
    /// Errors that can occur during socket operations.
    public enum Error: Swift.Error, Sendable {
        /// The descriptor is invalid.
        case handle(Kernel.Descriptor.Validity.Error)

        /// A platform-specific error.
        case platform(Kernel.Errno.Unmapped.Error)
    }
}

// MARK: - Equatable

extension Kernel.Socket.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Socket.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
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

extension Kernel.Socket.Error {
    @inlinable
    init(errno: Errno) {
        if let e = Kernel.Descriptor.Validity.Error(errno: errno) {
            self = .handle(e)
            return
        }
        self = .platform(Kernel.Errno.Unmapped.Error(errno: errno))
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

extension Kernel.Socket.Error {
    @inlinable
    init(windowsError error: DWORD) {
        if let e = Kernel.Descriptor.Validity.Error(windowsError: error) {
            self = .handle(e)
            return
        }
        self = .platform(Kernel.Errno.Unmapped.Error(windowsError: error))
    }

    @inlinable
    static func current() -> Self {
        Self(windowsError: DWORD(WSAGetLastError()))
    }
}

#endif

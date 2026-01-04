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

extension Kernel.IO.Read {
    /// Errors that can occur during read operations.
    public enum Error: Swift.Error, Sendable {
        case handle(Kernel.Descriptor.Validity.Error)
        case signal(Kernel.Signal.Error)
        case blocking(Kernel.IO.Blocking.Error)
        case io(Kernel.IO.Error)
        case memory(Kernel.Memory.Error)
        case platform(Kernel.Errno.Unmapped.Error)
    }
}

// MARK: - Equatable

extension Kernel.IO.Read.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.signal(let l), .signal(let r)): return l == r
        case (.blocking(let l), .blocking(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.memory(let l), .memory(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.IO.Read.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
        case .signal(let e): return "signal: \(e)"
        case .blocking(let e): return "blocking: \(e)"
        case .io(let e): return "io: \(e)"
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

    extension Kernel.IO.Read.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Descriptor.Validity.Error(errno: errno) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Signal.Error(errno: errno) {
                self = .signal(e)
                return
            }
            if let e = Kernel.IO.Blocking.Error(errno: errno) {
                self = .blocking(e)
                return
            }
            if let e = Kernel.IO.Error(errno: errno) {
                self = .io(e)
                return
            }
            if let e = Kernel.Memory.Error(errno: errno) {
                self = .memory(e)
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

    extension Kernel.IO.Read.Error {
        @inlinable
        init(windowsError error: DWORD) {
            if let e = Kernel.Descriptor.Validity.Error(windowsError: error) {
                self = .handle(e)
                return
            }
            if let e = Kernel.IO.Error(windowsError: error) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Errno.Unmapped.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: GetLastError())
        }
    }

#endif

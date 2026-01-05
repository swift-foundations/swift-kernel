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

extension Kernel.File.Open {
    public enum Error: Swift.Error, Sendable {
        case path(Kernel.Path.Resolution.Error)
        case permission(Kernel.Permission.Error)
        case handle(Kernel.Descriptor.Validity.Error)
        case signal(Kernel.Signal.Error)
        case space(Kernel.Storage.Error)
        case io(Kernel.IO.Error)
        case platform(Kernel.Error.Unmapped.Error)
    }
}

extension Kernel.File.Open.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.path(let l), .path(let r)): return l == r
        case (.permission(let l), .permission(let r)): return l == r
        case (.handle(let l), .handle(let r)): return l == r
        case (.signal(let l), .signal(let r)): return l == r
        case (.space(let l), .space(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

extension Kernel.File.Open.Error: CustomStringConvertible {
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

// MARK: - POSIX Error Mapping

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.File.Open.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Path.Resolution.Error(errno: errno) {
                self = .path(e)
                return
            }
            if let e = Kernel.Permission.Error(errno: errno) {
                self = .permission(e)
                return
            }
            if let e = Kernel.Descriptor.Validity.Error(errno: errno) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Signal.Error(errno: errno) {
                self = .signal(e)
                return
            }
            if let e = Kernel.Storage.Error(errno: errno) {
                self = .space(e)
                return
            }
            if let e = Kernel.IO.Error(errno: errno) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Error.Unmapped.Error(errno: errno))
        }

        @inlinable
        static func current() -> Self {
            Self(errno: Errno(rawValue: errno))
        }
    }

#endif

// MARK: - Windows Error Mapping

#if os(Windows)
    public import WinSDK

    extension Kernel.File.Open.Error {
        @inlinable
        init(windowsError error: DWORD) {
            if let e = Kernel.Path.Resolution.Error(windowsError: error) {
                self = .path(e)
                return
            }
            if let e = Kernel.Permission.Error(windowsError: error) {
                self = .permission(e)
                return
            }
            if let e = Kernel.Descriptor.Validity.Error(windowsError: error) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Storage.Error(windowsError: error) {
                self = .space(e)
                return
            }
            if let e = Kernel.IO.Error(windowsError: error) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Error.Unmapped.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: GetLastError())
        }
    }

#endif

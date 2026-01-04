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

extension Kernel.File.System.Stats {
    /// Error type for filesystem statistics operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        case path(Kernel.Path.Resolution.Error)
        case handle(Kernel.Descriptor.Validity.Error)
        case permission(Kernel.Permission.Error)
        case memory(Kernel.Memory.Error)
        case io(Kernel.IO.Error)
        case platform(Kernel.Errno.Unmapped.Error)
    }
}

extension Kernel.File.System.Stats.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let e): return "path: \(e)"
        case .handle(let e): return "handle: \(e)"
        case .permission(let e): return "permission: \(e)"
        case .memory(let e): return "memory: \(e)"
        case .io(let e): return "io: \(e)"
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
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.File.System.Stats.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Path.Resolution.Error(errno: errno) {
                self = .path(e)
                return
            }
            if let e = Kernel.Descriptor.Validity.Error(errno: errno) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Permission.Error(errno: errno) {
                self = .permission(e)
                return
            }
            if let e = Kernel.Memory.Error(errno: errno) {
                self = .memory(e)
                return
            }
            if let e = Kernel.IO.Error(errno: errno) {
                self = .io(e)
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

    extension Kernel.File.System.Stats.Error {
        @inlinable
        init(windowsError error: DWORD) {
            if let e = Kernel.Path.Resolution.Error(windowsError: error) {
                self = .path(e)
                return
            }
            if let e = Kernel.Descriptor.Validity.Error(windowsError: error) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Permission.Error(windowsError: error) {
                self = .permission(e)
                return
            }
            if let e = Kernel.Memory.Error(windowsError: error) {
                self = .memory(e)
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

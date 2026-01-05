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

public import SystemPackage

extension Kernel.File.Control {
    public enum Error: Swift.Error, Sendable {
        case handle(Kernel.Descriptor.Validity.Error)
        case io(Kernel.IO.Error)
        case platform(Kernel.Error.Unmapped.Error)
    }
}

extension Kernel.File.Control.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

extension Kernel.File.Control.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
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

    extension Kernel.File.Control.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Descriptor.Validity.Error(errno: errno) {
                self = .handle(e)
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

    extension Kernel.File.Control.Error {
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
            self = .platform(Kernel.Error.Unmapped.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: GetLastError())
        }
    }

#endif

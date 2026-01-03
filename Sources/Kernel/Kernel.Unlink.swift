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

// MARK: - Unlink Error Type

extension Kernel {
    public enum Unlink: Sendable {
        public enum Error: Swift.Error, Sendable {
            case path(Kernel.Path.Resolution.Error)
            case permission(Kernel.Permission.Error)
            case io(Kernel.IO.Error)
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Unlink.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.path(let l), .path(let r)): return l == r
        case (.permission(let l), .permission(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

extension Kernel.Unlink.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let e): return "path: \(e)"
        case .permission(let e): return "permission: \(e)"
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

    extension Kernel.Unlink.Error {
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
            if let e = Kernel.IO.Error(errno: errno) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Platform.Error(errno: errno))
        }

        @inlinable
        static func current() -> Self {
            Self(errno: Errno(rawValue: errno))
        }
    }

    extension Kernel.Unlink {
        /// Removes a file or symbolic link.
        ///
        /// - Parameter path: The path to the file to remove.
        /// - Throws: `Kernel.Unlink.Error` on failure.
        @inlinable
        public static func unlink(_ path: FilePath) throws(Error) {
            let result = path.withPlatformString { cPath in
                _cUnlink(cPath)
            }
            guard result == 0 else {
                throw .current()
            }
        }

        /// Removes a file or symbolic link.
        ///
        /// - Parameter path: The path to the file to remove as a C string.
        /// - Throws: `Kernel.Unlink.Error` on failure.
        @inlinable
        public static func unlink(_ path: UnsafePointer<CChar>) throws(Error) {
            guard _cUnlink(path) == 0 else {
                throw .current()
            }
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.Unlink.Error {
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
            if let e = Kernel.IO.Error(windowsError: error) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Platform.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: GetLastError())
        }
    }

    extension Kernel.Unlink {
        /// Removes a file.
        ///
        /// - Parameter path: The path to the file to remove.
        /// - Throws: `Kernel.Unlink.Error` on failure.
        @inlinable
        public static func unlink(_ path: FilePath) throws(Error) {
            let result = path.withPlatformString { wPath in
                DeleteFileW(wPath)
            }
            guard result else {
                throw .current()
            }
        }
    }

#endif

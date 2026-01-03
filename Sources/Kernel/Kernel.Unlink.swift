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

// MARK: - Unlink Type

extension Kernel {
    /// Unlink operations.
    public enum Unlink: Sendable {

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

    extension Kernel.Unlink {
        /// Removes a file or symbolic link.
        ///
        /// - Parameter path: The path to the file to remove.
        /// - Throws: `Kernel.Unlink.Error` on failure.
        @inlinable
        public static func unlink(_ path: FilePath) throws(Error) {
            let result = path.withPlatformString { cPath in
                #if canImport(Darwin)
                    Darwin.unlink(cPath)
                #elseif canImport(Glibc)
                    Glibc.unlink(cPath)
                #elseif canImport(Musl)
                    Musl.unlink(cPath)
                #endif
            }
            try Kernel.Syscall.require(result, .equals(0), orThrow: Error.current())
        }

        /// Removes a file or symbolic link.
        ///
        /// - Parameter path: The path to the file to remove as a C string.
        /// - Throws: `Kernel.Unlink.Error` on failure.
        @inlinable
        public static func unlink(_ path: UnsafePointer<CChar>) throws(Error) {
            #if canImport(Darwin)
                try Kernel.Syscall.require(Darwin.unlink(path), .equals(0), orThrow: Error.current())
            #elseif canImport(Glibc)
                try Kernel.Syscall.require(Glibc.unlink(path), .equals(0), orThrow: Error.current())
            #elseif canImport(Musl)
                try Kernel.Syscall.require(Musl.unlink(path), .equals(0), orThrow: Error.current())
            #endif
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

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
            try Kernel.Syscall.require(result, .isTrue, orThrow: Error.current())
        }
    }

#endif

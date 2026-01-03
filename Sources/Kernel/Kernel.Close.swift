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

extension Kernel {
    public enum Close: Sendable {}
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

extension Kernel.Close {
    /// Closes a file descriptor.
    @inlinable
    public static func close(_ descriptor: Kernel.Descriptor) throws(Error) {
        guard descriptor.isValid else {
            throw .handle(.invalid)
        }
        #if canImport(Darwin)
        guard Darwin.close(descriptor.rawValue) == 0 else {
            throw .current()
        }
        #elseif canImport(Glibc)
        guard Glibc.close(descriptor.rawValue) == 0 else {
            throw .current()
        }
        #elseif canImport(Musl)
        guard Musl.close(descriptor.rawValue) == 0 else {
            throw .current()
        }
        #endif
    }
}

#endif

// MARK: - Windows Implementation

#if os(Windows)
public import WinSDK

extension Kernel.Close {
    /// Closes a file handle.
    @inlinable
    public static func close(_ descriptor: Kernel.Descriptor) throws(Error) {
        guard descriptor.isValid else {
            throw .handle(.invalid)
        }
        if CloseHandle(descriptor.rawValue) == false {
            throw .current()
        }
    }
}

#endif

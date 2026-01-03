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
    /// Socket shutdown operations.
    public enum Shutdown: Sendable {

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

extension Kernel.Shutdown {
    /// Shuts down part of a full-duplex connection.
    ///
    /// - Parameters:
    ///   - descriptor: The socket descriptor.
    ///   - how: Which half of the connection to shut down.
    /// - Throws: `Kernel.Shutdown.Error` on failure.
    @inlinable
    public static func shutdown(
        _ descriptor: Kernel.Descriptor,
        how: How
    ) throws(Error) {
        #if canImport(Darwin)
        let result = Darwin.shutdown(descriptor.rawValue, how.rawValue)
        #elseif canImport(Glibc)
        let result = Glibc.shutdown(descriptor.rawValue, how.rawValue)
        #elseif canImport(Musl)
        let result = Musl.shutdown(descriptor.rawValue, how.rawValue)
        #endif

        guard result == 0 else {
            throw .current()
        }
    }
}

#endif

// MARK: - Windows Implementation

#if os(Windows)
public import WinSDK

extension Kernel.Shutdown {
    /// Shuts down part of a full-duplex connection.
    ///
    /// - Parameters:
    ///   - descriptor: The socket descriptor.
    ///   - how: Which half of the connection to shut down.
    /// - Throws: `Kernel.Shutdown.Error` on failure.
    @inlinable
    public static func shutdown(
        _ descriptor: Kernel.Descriptor,
        how: How
    ) throws(Error) {
        let result = WinSDK.shutdown(descriptor.rawValue, how.windowsValue)
        guard result == 0 else {
            throw .current()
        }
    }
}

#endif

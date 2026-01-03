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

// MARK: - Shutdown Types

extension Kernel {
    /// Socket shutdown operations.
    public enum Shutdown: Sendable {
        /// Specifies which half of the connection to shut down.
        public enum How: Int32, Sendable {
            /// Shut down the read side of the connection.
            case read = 0       // SHUT_RD

            /// Shut down the write side of the connection.
            case write = 1      // SHUT_WR

            /// Shut down both read and write sides.
            case readWrite = 2  // SHUT_RDWR
        }

        /// Errors that can occur during shutdown operations.
        public enum Error: Swift.Error, Sendable {
            /// The descriptor is invalid.
            case handle(Kernel.Handle.Error)

            /// An I/O error occurred.
            case io(Kernel.IO.Error)

            /// A platform-specific error.
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Shutdown.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

extension Kernel.Shutdown.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
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

    extension Kernel.Shutdown.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Handle.Error(errno: errno) {
                self = .handle(e)
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

    extension Kernel.Shutdown.Error {
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
            self = .platform(Kernel.Platform.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: DWORD(WSAGetLastError()))
        }
    }

    extension Kernel.Shutdown.How {
        /// Converts to Windows SD_* constant.
        @usableFromInline
        internal var windowsValue: Int32 {
            switch self {
            case .read: return SD_RECEIVE
            case .write: return SD_SEND
            case .readWrite: return SD_BOTH
            }
        }
    }

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

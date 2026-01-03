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

// MARK: - Socket Types

extension Kernel {
    /// Socket operations.
    public enum Socket: Sendable {
        /// Errors that can occur during socket operations.
        public enum Error: Swift.Error, Sendable {
            /// The descriptor is invalid.
            case handle(Kernel.Handle.Error)

            /// A platform-specific error.
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Socket.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

extension Kernel.Socket.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
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

    extension Kernel.Socket.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Handle.Error(errno: errno) {
                self = .handle(e)
                return
            }
            self = .platform(Kernel.Platform.Error(errno: errno))
        }

        @inlinable
        static func current() -> Self {
            Self(errno: Errno(rawValue: errno))
        }
    }

    extension Kernel.Socket {
        /// Gets the pending socket error (SO_ERROR).
        ///
        /// This retrieves and clears the pending error on a socket.
        /// Commonly used after a non-blocking connect to check if the
        /// connection succeeded.
        ///
        /// - Parameter descriptor: The socket descriptor.
        /// - Returns: The error code (0 if no error).
        /// - Throws: `Kernel.Socket.Error` if getsockopt fails.
        @inlinable
        public static func getError(_ descriptor: Kernel.Descriptor) throws(Error) -> Int32 {
            var err: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)

            let rc = getsockopt(
                descriptor.rawValue,
                SOL_SOCKET,
                SO_ERROR,
                &err,
                &len
            )

            guard rc == 0 else {
                throw .current()
            }

            return err
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.Socket.Error {
        @inlinable
        init(windowsError error: DWORD) {
            if let e = Kernel.Handle.Error(windowsError: error) {
                self = .handle(e)
                return
            }
            self = .platform(Kernel.Platform.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: DWORD(WSAGetLastError()))
        }
    }

    extension Kernel.Socket {
        /// Gets the pending socket error (SO_ERROR).
        ///
        /// This retrieves and clears the pending error on a socket.
        /// Commonly used after a non-blocking connect to check if the
        /// connection succeeded.
        ///
        /// - Parameter descriptor: The socket descriptor.
        /// - Returns: The error code (0 if no error).
        /// - Throws: `Kernel.Socket.Error` if getsockopt fails.
        @inlinable
        public static func getError(_ descriptor: Kernel.Descriptor) throws(Error) -> Int32 {
            var err: Int32 = 0
            var len = Int32(MemoryLayout<Int32>.size)

            let rc = getsockopt(
                descriptor.rawValue,
                Int32(SOL_SOCKET),
                Int32(SO_ERROR),
                UnsafeMutablePointer(&err),
                &len
            )

            guard rc == 0 else {
                throw .current()
            }

            return err
        }
    }

#endif

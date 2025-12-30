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

// MARK: - Read Error Type

extension Kernel {
    public enum Read: Sendable {
        public enum Error: Swift.Error, Sendable {
            case handle(Kernel.Handle.Error)
            case signal(Kernel.Signal.Error)
            case blocking(Kernel.Blocking.Error)
            case io(Kernel.IO.Error)
            case memory(Kernel.Memory.Error)
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Read.Error: Equatable {
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

extension Kernel.Read.Error: CustomStringConvertible {
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

// MARK: - POSIX Implementation

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Read.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Handle.Error(errno: errno) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Signal.Error(errno: errno) {
                self = .signal(e)
                return
            }
            if let e = Kernel.Blocking.Error(errno: errno) {
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
            self = .platform(Kernel.Platform.Error(errno: errno))
        }

        @inlinable
        static func current() -> Self {
            Self(errno: Errno(rawValue: errno))
        }
    }

    extension Kernel.Read {
        /// Reads bytes from a file descriptor.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor to read from.
        ///   - buffer: The buffer to read into.
        /// - Returns: Number of bytes read. Returns 0 on EOF.
        /// - Throws: `Kernel.Read.Error` on failure.
        @inlinable
        public static func read(
            _ descriptor: Kernel.Descriptor,
            into buffer: UnsafeMutableRawBufferPointer
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor >= 0 else {
                throw .handle(.invalid)
            }
            let result = _cRead(descriptor, baseAddress, buffer.count)
            guard result >= 0 else {
                throw .current()
            }
            return result
        }

        /// Reads bytes from a file descriptor at a specific offset.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor to read from.
        ///   - buffer: The buffer to read into.
        ///   - offset: The file offset to read from.
        /// - Returns: Number of bytes read. Returns 0 on EOF.
        /// - Throws: `Kernel.Read.Error` on failure.
        @inlinable
        public static func pread(
            _ descriptor: Kernel.Descriptor,
            into buffer: UnsafeMutableRawBufferPointer,
            at offset: Int64
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor >= 0 else {
                throw .handle(.invalid)
            }
            let result = _cPread(descriptor, baseAddress, buffer.count, off_t(offset))
            guard result >= 0 else {
                throw .current()
            }
            return result
        }
    }

#endif

// MARK: - Span Adapters

extension Kernel.Read {
    /// Reads bytes from a file descriptor into a mutable span.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - span: The mutable span to read into.
    /// - Returns: Number of bytes read. Returns 0 on EOF.
    /// - Throws: `Kernel.Read.Error` on failure.
    @inlinable
    public static func read(
        _ descriptor: Kernel.Descriptor,
        into span: inout MutableSpan<UInt8>
    ) throws(Error) -> Int {
        try span.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) throws(Error) -> Int in
            try read(descriptor, into: buffer)
        }
    }

    /// Reads bytes from a file descriptor at a specific offset into a mutable span.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - span: The mutable span to read into.
    ///   - offset: The file offset to read from.
    /// - Returns: Number of bytes read. Returns 0 on EOF.
    /// - Throws: `Kernel.Read.Error` on failure.
    @inlinable
    public static func pread(
        _ descriptor: Kernel.Descriptor,
        into span: inout MutableSpan<UInt8>,
        at offset: Int64
    ) throws(Error) -> Int {
        try span.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) throws(Error) -> Int in
            try pread(descriptor, into: buffer, at: offset)
        }
    }
}

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.Read.Error {
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
            Self(windowsError: GetLastError())
        }
    }

    extension Kernel.Read {
        /// Reads bytes from a file handle.
        @inlinable
        public static func read(
            _ descriptor: Kernel.Descriptor,
            into buffer: UnsafeMutableRawBufferPointer
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor != INVALID_HANDLE_VALUE else {
                throw .handle(.invalid)
            }

            var bytesRead: DWORD = 0
            let result = ReadFile(
                descriptor,
                baseAddress,
                DWORD(min(buffer.count, Int(DWORD.max))),
                &bytesRead,
                nil
            )

            guard result != 0 else {
                let error = GetLastError()
                if error == DWORD(ERROR_HANDLE_EOF) {
                    return 0
                }
                throw Self.Error(windowsError: error)
            }
            return Int(bytesRead)
        }

        /// Reads bytes from a file handle at a specific offset.
        @inlinable
        public static func pread(
            _ descriptor: Kernel.Descriptor,
            into buffer: UnsafeMutableRawBufferPointer,
            at offset: Int64
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor != INVALID_HANDLE_VALUE else {
                throw .handle(.invalid)
            }

            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(offset & 0xFFFF_FFFF)
            overlapped.OffsetHigh = DWORD(offset >> 32)

            var bytesRead: DWORD = 0
            let result = ReadFile(
                descriptor,
                baseAddress,
                DWORD(min(buffer.count, Int(DWORD.max))),
                &bytesRead,
                &overlapped
            )

            guard result != 0 else {
                let error = GetLastError()
                if error == DWORD(ERROR_HANDLE_EOF) {
                    return 0
                }
                throw Self.Error(windowsError: error)
            }
            return Int(bytesRead)
        }
    }

#endif

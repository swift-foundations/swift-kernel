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

// MARK: - Write Error Type

extension Kernel {
    public enum Write: Sendable {
        public enum Error: Swift.Error, Sendable {
            case handle(Kernel.Handle.Error)
            case signal(Kernel.Signal.Error)
            case blocking(Kernel.Blocking.Error)
            case io(Kernel.IO.Error)
            case space(Kernel.Space.Error)
            case memory(Kernel.Memory.Error)
            case platform(Kernel.Platform.Error)
        }
    }
}

extension Kernel.Write.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.signal(let l), .signal(let r)): return l == r
        case (.blocking(let l), .blocking(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.space(let l), .space(let r)): return l == r
        case (.memory(let l), .memory(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        default: return false
        }
    }
}

extension Kernel.Write.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
        case .signal(let e): return "signal: \(e)"
        case .blocking(let e): return "blocking: \(e)"
        case .io(let e): return "io: \(e)"
        case .space(let e): return "space: \(e)"
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

    extension Kernel.Write.Error {
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
            if let e = Kernel.Space.Error(errno: errno) {
                self = .space(e)
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

    extension Kernel.Write {
        /// Writes bytes to a file descriptor.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor to write to.
        ///   - buffer: The buffer to write from.
        /// - Returns: Number of bytes written (may be less than buffer.count).
        /// - Throws: `Kernel.Write.Error` on failure.
        @inlinable
        public static func write(
            _ descriptor: Kernel.Descriptor,
            from buffer: UnsafeRawBufferPointer
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor.isValid else {
                throw .handle(.invalid)
            }
            let result = _cWrite(descriptor.rawValue, baseAddress, buffer.count)
            guard result >= 0 else {
                throw .current()
            }
            return result
        }

        /// Writes bytes to a file descriptor at a specific offset.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor to write to.
        ///   - buffer: The buffer to write from.
        ///   - offset: The file offset to write at.
        /// - Returns: Number of bytes written (may be less than buffer.count).
        /// - Throws: `Kernel.Write.Error` on failure.
        @inlinable
        public static func pwrite(
            _ descriptor: Kernel.Descriptor,
            from buffer: UnsafeRawBufferPointer,
            at offset: Int64
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor.isValid else {
                throw .handle(.invalid)
            }
            let result = _cPwrite(descriptor.rawValue, baseAddress, buffer.count, off_t(offset))
            guard result >= 0 else {
                throw .current()
            }
            return result
        }
    }

#endif

// MARK: - Span Adapters

extension Kernel.Write {
    /// Writes bytes from a span to a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - span: The span containing bytes to write.
    /// - Returns: Number of bytes written.
    /// - Throws: `Kernel.Write.Error` on failure.
    @inlinable
    public static func write(
        _ descriptor: Kernel.Descriptor,
        from span: Span<UInt8>
    ) throws(Error) -> Int {
        try span.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws(Error) -> Int in
            try write(descriptor, from: buffer)
        }
    }

    /// Writes bytes from a span to a file descriptor at a specific offset.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - span: The span containing bytes to write.
    ///   - offset: The file offset to write at.
    /// - Returns: Number of bytes written.
    /// - Throws: `Kernel.Write.Error` on failure.
    @inlinable
    public static func pwrite(
        _ descriptor: Kernel.Descriptor,
        from span: Span<UInt8>,
        at offset: Int64
    ) throws(Error) -> Int {
        try span.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws(Error) -> Int in
            try pwrite(descriptor, from: buffer, at: offset)
        }
    }
}

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.Write.Error {
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
            if let e = Kernel.Space.Error(windowsError: error) {
                self = .space(e)
                return
            }
            self = .platform(Kernel.Platform.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: GetLastError())
        }
    }

    extension Kernel.Write {
        /// Writes bytes to a file handle.
        @inlinable
        public static func write(
            _ descriptor: Kernel.Descriptor,
            from buffer: UnsafeRawBufferPointer
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor.isValid else {
                throw .handle(.invalid)
            }

            var bytesWritten: DWORD = 0
            let result = WriteFile(
                descriptor.rawValue,
                baseAddress,
                DWORD(min(buffer.count, Int(DWORD.max))),
                &bytesWritten,
                nil
            )

            guard result else {
                throw .current()
            }
            return Int(bytesWritten)
        }

        /// Writes bytes to a file handle at a specific offset.
        @inlinable
        public static func pwrite(
            _ descriptor: Kernel.Descriptor,
            from buffer: UnsafeRawBufferPointer,
            at offset: Int64
        ) throws(Error) -> Int {
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            guard descriptor.isValid else {
                throw .handle(.invalid)
            }

            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(offset & 0xFFFF_FFFF)
            overlapped.OffsetHigh = DWORD(offset >> 32)

            var bytesWritten: DWORD = 0
            let result = WriteFile(
                descriptor.rawValue,
                baseAddress,
                DWORD(min(buffer.count, Int(DWORD.max))),
                &bytesWritten,
                &overlapped
            )

            guard result else {
                throw .current()
            }
            return Int(bytesWritten)
        }
    }

#endif

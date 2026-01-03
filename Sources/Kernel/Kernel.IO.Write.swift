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

// MARK: - Write Type

extension Kernel.IO {
    /// Write operations.
    public enum Write: Sendable {

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

    extension Kernel.IO.Write {
        /// Writes bytes to a file descriptor.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor to write to.
        ///   - buffer: The buffer to write from.
        /// - Returns: Number of bytes written (may be less than buffer.count).
        /// - Throws: `Kernel.IO.Write.Error` on failure.
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
            #if canImport(Darwin)
            let result = Darwin.write(descriptor.rawValue, baseAddress, buffer.count)
            #elseif canImport(Glibc)
            let result = Glibc.write(descriptor.rawValue, baseAddress, buffer.count)
            #elseif canImport(Musl)
            let result = Musl.write(descriptor.rawValue, baseAddress, buffer.count)
            #endif
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
        /// - Throws: `Kernel.IO.Write.Error` on failure.
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
            #if canImport(Darwin)
            let result = Darwin.pwrite(descriptor.rawValue, baseAddress, buffer.count, off_t(offset))
            #elseif canImport(Glibc)
            let result = Glibc.pwrite(descriptor.rawValue, baseAddress, buffer.count, off_t(offset))
            #elseif canImport(Musl)
            let result = Musl.pwrite(descriptor.rawValue, baseAddress, buffer.count, off_t(offset))
            #endif
            guard result >= 0 else {
                throw .current()
            }
            return result
        }
    }

#endif

// MARK: - Span Adapters

extension Kernel.IO.Write {
    /// Writes bytes from a span to a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - span: The span containing bytes to write.
    /// - Returns: Number of bytes written.
    /// - Throws: `Kernel.IO.Write.Error` on failure.
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
    /// - Throws: `Kernel.IO.Write.Error` on failure.
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

    extension Kernel.IO.Write {
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

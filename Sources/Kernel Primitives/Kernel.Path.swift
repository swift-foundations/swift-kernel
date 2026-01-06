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

#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif canImport(Musl)
    internal import Musl
#elseif os(Windows)
    internal import ucrt
#endif

extension Kernel {
    /// An unsafe, borrow-only path wrapper for syscall use.
    ///
    /// `Kernel.Path` is a thin wrapper over a null-terminated platform string pointer.
    /// It is **explicitly unsafe** and **non-Sendable**:
    /// - The caller must ensure the pointer remains valid for the path's lifetime
    /// - The caller must ensure the string is properly null-terminated
    /// - This type does NOT own the memory it points to
    ///
    /// ## Platform Notes
    ///
    /// - On POSIX: Uses narrow strings (`CChar`/UTF-8)
    /// - On Windows: Uses wide strings (`UInt16`/UTF-16)
    ///
    /// ## Recommended Usage
    ///
    /// Use `Kernel.Path.withCString` to safely convert a String to a path:
    /// ```swift
    /// let fd = try Kernel.Path.withCString("/tmp/file.txt") { path in
    ///     try Kernel.File.Open.open(path: path, mode: .read, options: [], permissions: 0)
    /// }
    /// ```
    ///
    /// Only use `Kernel.Path` directly when you have a pre-validated platform string:
    /// ```swift
    /// someCString.withCString { cString in
    ///     let path = Kernel.Path(unsafeCString: cString)
    ///     // path is only valid within this closure
    /// }
    /// ```
    ///
    /// - Warning: This type is intentionally NOT `Sendable`. Pointer lifetimes
    ///   cannot be safely transferred across concurrency boundaries.
    public struct Path: ~Copyable {
        /// The underlying null-terminated platform string.
        ///
        /// - Warning: This pointer is NOT owned. The caller must ensure validity.
        public let cString: UnsafePointer<Char>
    }
}

// MARK: - Platform Character Type

extension Kernel.Path {
    /// Platform-native path character type.
    ///
    /// - POSIX (macOS, Linux): `CChar` (Int8, UTF-8)
    /// - Windows: `UInt16` (UTF-16)
    #if os(Windows)
        public typealias Char = UInt16
    #else
        public typealias Char = CChar
    #endif
}

// MARK: - Initialization

extension Kernel.Path {
    /// Creates an unsafe path from a platform string pointer.
    ///
    /// - Parameter cString: A pointer to a null-terminated platform string.
    ///
    /// - Warning: No validation is performed. The caller must ensure:
    ///   - The string is properly null-terminated
    ///   - The pointer remains valid for the lifetime of this `Path`
    ///   - The string does not contain interior NUL bytes
    @inlinable
    public init(unsafeCString cString: UnsafePointer<Char>) {
        self.cString = cString
    }
}

// MARK: - String Integration

extension Kernel.Path {
    /// Executes a closure with a borrowed path from a String.
    ///
    /// This is the recommended way to use paths with Kernel syscalls.
    /// The closure receives a `Kernel.Path` that is only valid for the
    /// duration of the closure.
    ///
    /// - Parameters:
    ///   - string: The path string (UTF-8 on POSIX, converted to UTF-16 on Windows).
    ///   - body: A typed-throwing closure that receives the borrowed path.
    /// - Returns: The value returned by the closure.
    /// - Throws: The typed error from the closure.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fd = try Kernel.Path.withCString("/tmp/file.txt") { path in
    ///     try Kernel.File.Open.open(path: path, mode: .read, options: [], permissions: 0)
    /// }
    /// ```
    @inlinable
    public static func withCString<R: ~Copyable, E: Swift.Error>(
        _ string: Swift.String,
        _ body: (borrowing Kernel.Path) throws(E) -> R
    ) throws(E) -> R {
        #if os(Windows)
        let utf16 = string.utf16
        let count = utf16.count + 1
        let buffer = UnsafeMutablePointer<UInt16>.allocate(capacity: count)
        defer { buffer.deallocate() }
        var i = 0
        for unit in utf16 {
            buffer[i] = unit
            i += 1
        }
        buffer[i] = 0 // NUL terminator
        return try body(Kernel.Path(unsafeCString: buffer))
        #else
        let utf8 = string.utf8
        let count = utf8.count + 1
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: count)
        defer { buffer.deallocate() }
        var i = 0
        for byte in utf8 {
            buffer[i] = CChar(bitPattern: byte)
            i += 1
        }
        buffer[i] = 0 // NUL terminator
        return try body(Kernel.Path(unsafeCString: buffer))
        #endif
    }
}

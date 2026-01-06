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

// MARK: - Layer 1: String Convenience (Allocates)
//
// These methods convert Swift Strings to Kernel.Path instances.
// They allocate temporary buffers and are NOT suitable for strict embedded contexts.
// For Layer 0 (zero-allocation), use the pointer-based initializers in Kernel Primitives.
//
// Note: Parameter packs cannot express `repeat Kernel.Path` because pack expansions
// require a type that references `each S`. Since `Kernel.Path` is a fixed type,
// we provide fixed-arity overloads for the common cases (1, 2, and 3 paths).

public import Kernel_Primitives

// MARK: - Single Path

extension Kernel.Path {
    /// Executes a closure with a borrowed path from a String.
    ///
    /// This is the recommended way to use paths with Kernel syscalls.
    /// The closure receives a `Kernel.Path` that is only valid for the
    /// duration of the closure.
    ///
    /// - Note: This method allocates a temporary buffer for the C string.
    ///   For strict embedded contexts, use the pointer-based initializer instead.
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
    public static func withCString<S: StringProtocol, R: ~Copyable, E: Swift.Error>(
        _ string: S,
        _ body: (borrowing Kernel.Path) throws(E) -> R
    ) throws(E) -> R {
        #if os(Windows)
        let buffer = _allocateUTF16Buffer(string)
        defer { buffer.deallocate() }
        return try body(Kernel.Path(unsafeCString: buffer))
        #else
        let buffer = _allocateUTF8Buffer(string)
        defer { buffer.deallocate() }
        return try body(Kernel.Path(unsafeCString: buffer))
        #endif
    }
}

// MARK: - Two Paths

extension Kernel.Path {
    /// Executes a closure with two borrowed paths from Strings.
    ///
    /// Both paths are valid only for the duration of the closure.
    /// This is useful for operations like clone, copy, rename, link, or symlink
    /// that take source and destination paths.
    ///
    /// - Note: This method allocates temporary buffers for each C string.
    ///
    /// - Parameters:
    ///   - string1: The first path string.
    ///   - string2: The second path string.
    ///   - body: A closure that receives both borrowed paths.
    /// - Returns: The value returned by the closure.
    /// - Throws: The typed error from the closure.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try Kernel.Path.withCStrings("/src", "/dst") { src, dst in
    ///     try Kernel.File.Clone.clone(from: src, to: dst, behavior: .copyOnly)
    /// }
    /// ```
    @inlinable
    public static func withCStrings<S1: StringProtocol, S2: StringProtocol, R: ~Copyable, E: Swift.Error>(
        _ string1: S1,
        _ string2: S2,
        _ body: (borrowing Kernel.Path, borrowing Kernel.Path) throws(E) -> R
    ) throws(E) -> R {
        #if os(Windows)
        let buffer1 = _allocateUTF16Buffer(string1)
        defer { buffer1.deallocate() }
        let buffer2 = _allocateUTF16Buffer(string2)
        defer { buffer2.deallocate() }
        return try body(
            Kernel.Path(unsafeCString: buffer1),
            Kernel.Path(unsafeCString: buffer2)
        )
        #else
        let buffer1 = _allocateUTF8Buffer(string1)
        defer { buffer1.deallocate() }
        let buffer2 = _allocateUTF8Buffer(string2)
        defer { buffer2.deallocate() }
        return try body(
            Kernel.Path(unsafeCString: buffer1),
            Kernel.Path(unsafeCString: buffer2)
        )
        #endif
    }
}

// MARK: - Three Paths

extension Kernel.Path {
    /// Executes a closure with three borrowed paths from Strings.
    ///
    /// All paths are valid only for the duration of the closure.
    ///
    /// - Note: This method allocates temporary buffers for each C string.
    ///
    /// - Parameters:
    ///   - string1: The first path string.
    ///   - string2: The second path string.
    ///   - string3: The third path string.
    ///   - body: A closure that receives all three borrowed paths.
    /// - Returns: The value returned by the closure.
    /// - Throws: The typed error from the closure.
    @inlinable
    public static func withCStrings<S1: StringProtocol, S2: StringProtocol, S3: StringProtocol, R: ~Copyable, E: Swift.Error>(
        _ string1: S1,
        _ string2: S2,
        _ string3: S3,
        _ body: (borrowing Kernel.Path, borrowing Kernel.Path, borrowing Kernel.Path) throws(E) -> R
    ) throws(E) -> R {
        #if os(Windows)
        let buffer1 = _allocateUTF16Buffer(string1)
        defer { buffer1.deallocate() }
        let buffer2 = _allocateUTF16Buffer(string2)
        defer { buffer2.deallocate() }
        let buffer3 = _allocateUTF16Buffer(string3)
        defer { buffer3.deallocate() }
        return try body(
            Kernel.Path(unsafeCString: buffer1),
            Kernel.Path(unsafeCString: buffer2),
            Kernel.Path(unsafeCString: buffer3)
        )
        #else
        let buffer1 = _allocateUTF8Buffer(string1)
        defer { buffer1.deallocate() }
        let buffer2 = _allocateUTF8Buffer(string2)
        defer { buffer2.deallocate() }
        let buffer3 = _allocateUTF8Buffer(string3)
        defer { buffer3.deallocate() }
        return try body(
            Kernel.Path(unsafeCString: buffer1),
            Kernel.Path(unsafeCString: buffer2),
            Kernel.Path(unsafeCString: buffer3)
        )
        #endif
    }
}

// MARK: - Buffer Allocation Helpers

#if os(Windows)
@usableFromInline
internal func _allocateUTF16Buffer<S: StringProtocol>(_ string: S) -> UnsafeMutablePointer<UInt16> {
    let s = Swift.String(string)
    let utf16 = s.utf16
    let count = utf16.count + 1
    let buffer = UnsafeMutablePointer<UInt16>.allocate(capacity: count)
    var i = 0
    for unit in utf16 {
        buffer[i] = unit
        i += 1
    }
    buffer[i] = 0
    return buffer
}
#else
@usableFromInline
internal func _allocateUTF8Buffer<S: StringProtocol>(_ string: S) -> UnsafeMutablePointer<CChar> {
    let s = Swift.String(string)
    let utf8 = s.utf8
    let count = utf8.count + 1
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: count)
    var i = 0
    for byte in utf8 {
        buffer[i] = CChar(bitPattern: byte)
        i += 1
    }
    buffer[i] = 0
    return buffer
}
#endif

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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
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
    /// For safe path handling, prefer the `FilePath`-based syscall overloads:
    /// ```swift
    /// let path = FilePath("/tmp/file.txt")
    /// let fd = try Kernel.Open.open(path: path, mode: .read, options: [], permissions: 0)
    /// ```
    ///
    /// Only use `Kernel.Path` when you have a pre-validated platform string and need
    /// to avoid the FilePath conversion overhead:
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
        public let cString: UnsafePointer<CInterop.PlatformChar>
    }
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
    public init(unsafeCString cString: UnsafePointer<CInterop.PlatformChar>) {
        self.cString = cString
    }
}

// MARK: - FilePath Integration

extension Kernel {
    /// Calls a typed-throwing closure with a platform string pointer.
    ///
    /// This wrapper preserves 100% typed throws when using `FilePath.withPlatformString`,
    /// which uses `rethrows` and would otherwise erase typed error information.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - body: A typed-throwing closure that receives the platform string pointer.
    /// - Returns: The value returned by the closure.
    /// - Throws: The typed error from the closure.
    @inlinable
    public static func withPlatformString<R, E: Swift.Error>(
        _ path: FilePath,
        _ body: (UnsafePointer<CInterop.PlatformChar>) throws(E) -> R
    ) throws(E) -> R {
        let ps = PlatformString(copying: path)
        return try body(ps.pointer)
    }

    /// Executes a closure with a path suitable for syscall use.
    ///
    /// This is the safe way to use paths with Kernel syscalls. It leverages
    /// `FilePath.withPlatformString` internally to ensure proper lifetime
    /// and null-termination, while preserving 100% typed throws.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - body: A closure that receives the path for syscall use.
    /// - Returns: The value returned by the closure.
    /// - Throws: The typed error from the closure.
    @inlinable
    public static func withPath<R>(
        _ path: FilePath,
        _ body: (borrowing Path) throws(Kernel.Error) -> R
    ) throws(Kernel.Error) -> R {
        try Kernel.withPlatformString(path) { (cString: UnsafePointer<CInterop.PlatformChar>) throws(Kernel.Error) -> R in
            try body(Path(unsafeCString: cString))
        }
    }
}

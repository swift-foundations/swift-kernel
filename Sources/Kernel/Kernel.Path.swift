//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#endif

public import SystemPackage

extension Kernel {
    /// An unsafe, borrow-only path wrapper for syscall use.
    ///
    /// `Kernel.Path` is a thin wrapper over a null-terminated C string pointer.
    /// It is **explicitly unsafe** and **non-Sendable**:
    /// - The caller must ensure the pointer remains valid for the path's lifetime
    /// - The caller must ensure the string is properly null-terminated
    /// - This type does NOT own the memory it points to
    ///
    /// ## Recommended Usage
    ///
    /// For safe path handling, prefer the `FilePath`-based syscall overloads:
    /// ```swift
    /// let path = FilePath("/tmp/file.txt")
    /// let fd = try Kernel.Syscalls.open(path: path, mode: .read, options: [], permissions: 0)
    /// ```
    ///
    /// Only use `Kernel.Path` when you have a pre-validated C string and need
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
        /// The underlying null-terminated C string.
        ///
        /// - Warning: This pointer is NOT owned. The caller must ensure validity.
        public let cString: UnsafePointer<CChar>

        /// Creates an unsafe path from a C string pointer.
        ///
        /// - Parameter cString: A pointer to a null-terminated C string.
        ///
        /// - Warning: No validation is performed. The caller must ensure:
        ///   - The string is properly null-terminated
        ///   - The pointer remains valid for the lifetime of this `Path`
        ///   - The string does not contain interior NUL bytes
        @inlinable
        public init(unsafeCString cString: UnsafePointer<CChar>) {
            self.cString = cString
        }
    }
}

// MARK: - FilePath Integration

extension Kernel {
    /// Executes a closure with a path suitable for syscall use.
    ///
    /// This is the safe way to use paths with Kernel syscalls. It leverages
    /// `FilePath.withPlatformString` internally to ensure proper lifetime
    /// and null-termination.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - body: A closure that receives the path for syscall use.
    /// - Returns: The value returned by the closure.
    /// - Throws: Any error thrown by the closure.
    public static func withPath<R>(
        _ path: FilePath,
        _ body: (borrowing Path) throws(Kernel.Error) -> R
    ) throws(Kernel.Error) -> R {
        do {
            return try path.withPlatformString { cString in
                try body(Path(unsafeCString: cString))
            }
        } catch let error as Kernel.Error {
            throw error
        } catch {
            throw .platform(code: -1, message: "Unexpected error: \(error)")
        }
    }
}

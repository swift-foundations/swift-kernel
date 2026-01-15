// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Swift.String to Kernel.String

#if !os(Windows)

extension Kernel.String {
    /// Creates an owned kernel string from a Swift String.
    ///
    /// Allocates new storage and copies the UTF-8 content.
    ///
    /// - Parameter string: The Swift string to convert.
    @inlinable
    public init(_ string: Swift.String) {
        let utf8 = string.utf8
        let count = utf8.count
        let buffer = UnsafeMutablePointer<Kernel.String.Char>.allocate(capacity: count + 1)

        var index = 0
        for byte in utf8 {
            buffer[index] = Kernel.String.Char(bitPattern: byte)
            index += 1
        }
        buffer[count] = Kernel.String.terminator

        self.init(adopting: buffer, count: count)
    }
}

#endif

#if os(Windows)

extension Kernel.String {
    /// Creates an owned kernel string from a Swift String.
    ///
    /// Allocates new storage and copies the UTF-16 content.
    ///
    /// - Parameter string: The Swift string to convert.
    @inlinable
    public init(_ string: Swift.String) {
        let utf16 = Array(string.utf16)
        let count = utf16.count
        let buffer = UnsafeMutablePointer<Kernel.String.Char>.allocate(capacity: count + 1)

        for (index, unit) in utf16.enumerated() {
            buffer[index] = unit
        }
        buffer[count] = Kernel.String.terminator

        self.init(adopting: buffer, count: count)
    }
}

#endif

// MARK: - Kernel.String to Swift.String

#if !os(Windows)

extension Swift.String {
    /// Creates a Swift String from a kernel string view.
    ///
    /// - Parameter view: The kernel string view to convert.
    @inlinable
    public init(_ view: borrowing Kernel.String.View) {
        self = Swift.String(cString: view.pointer)
    }

    /// Creates a Swift String from an owned kernel string.
    ///
    /// - Parameter string: The kernel string to convert.
    @inlinable
    public init(_ string: borrowing Kernel.String) {
        let str = string.withUnsafePointer { pointer in
            Swift.String(cString: pointer)
        }
        self = str
    }
}

#endif

#if os(Windows)

extension Swift.String {
    /// Creates a Swift String from a kernel string view.
    ///
    /// - Parameter view: The kernel string view to convert.
    @inlinable
    public init(_ view: borrowing Kernel.String.View) {
        let span = view.span
        self = span.withUnsafeBufferPointer { buffer in
            Swift.String(decoding: buffer, as: UTF16.self)
        }
    }

    /// Creates a Swift String from an owned kernel string.
    ///
    /// - Parameter string: The kernel string to convert.
    @inlinable
    public init(_ string: borrowing Kernel.String) {
        let span = string.span
        self = span.withUnsafeBufferPointer { buffer in
            Swift.String(decoding: buffer, as: UTF16.self)
        }
    }
}

#endif

// MARK: - Convenience: Execute with Kernel.String

extension Swift.String {
    /// Namespace for kernel string operations.
    public struct WithKernelString: Sendable {
        @usableFromInline
        internal let string: Swift.String

        @usableFromInline
        internal init(_ string: Swift.String) {
            self.string = string
        }
    }

    /// Access to kernel string operations.
    @inlinable
    public var withKernelString: WithKernelString {
        WithKernelString(self)
    }
}

extension Swift.String.WithKernelString {
    /// Executes a closure with a temporary kernel string pointer.
    ///
    /// The pointer is only valid for the duration of the closure.
    /// The closure cannot return ~Escapable or ~Copyable values as the
    /// underlying `withCString` doesn't support them.
    ///
    /// - Parameter body: A closure that receives the kernel string pointer.
    /// - Returns: The result of the closure.
    @inlinable
    public func callAsFunction<R, E: Swift.Error>(
        _ body: (UnsafePointer<Kernel.String.Char>) throws(E) -> R
    ) throws(E) -> R {
        // Use Result to bridge typed throws across non-typed-throws boundary
        var result: Result<R, E>!
        #if os(Windows)
        var utf16 = Array(string.utf16)
        utf16.append(0) // null terminator
        utf16.withUnsafeBufferPointer { buffer in
            do throws(E) {
                result = .success(try body(buffer.baseAddress!))
            } catch {
                result = .failure(error)
            }
        }
        #else
        string.withCString { pointer in
            do throws(E) {
                result = .success(try body(pointer))
            } catch {
                result = .failure(error)
            }
        }
        #endif
        return try result.get()
    }

    /// Executes a closure with an owned kernel string.
    ///
    /// Creates `Kernel.String` storage, then provides a view.
    /// This path supports ~Copyable results and enables lifetime-tied views
    /// (View, Span) because the owned storage outlives the closure.
    ///
    /// - Parameter body: A closure that receives a kernel string view.
    /// - Returns: The result of the closure.
    @inlinable
    public func owned<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing Kernel.String.View) throws(E) -> R
    ) throws(E) -> R {
        let string = Kernel.String(string)
        return try body(string.view)
    }
}

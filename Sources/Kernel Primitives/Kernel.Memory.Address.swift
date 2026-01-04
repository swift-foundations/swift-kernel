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

extension Kernel.Memory {
    /// A memory address.
    ///
    /// Type alias for `UnsafeMutableRawPointer` providing semantic clarity
    /// in memory mapping APIs.
    public typealias Address = UnsafeMutableRawPointer
}

// MARK: - Typed Pointer Arithmetic

extension UnsafeMutableRawPointer {
    /// Returns a pointer offset by the given file size.
    ///
    /// - Parameter size: The byte offset as a typed file size.
    /// - Returns: A pointer advanced by the size's byte count.
    @inlinable
    public func advanced(by size: Kernel.File.Size) -> UnsafeMutableRawPointer {
        advanced(by: Int(size))
    }
}

extension UnsafeRawPointer {
    /// Returns a pointer offset by the given file size.
    ///
    /// - Parameter size: The byte offset as a typed file size.
    /// - Returns: A pointer advanced by the size's byte count.
    @inlinable
    public func advanced(by size: Kernel.File.Size) -> UnsafeRawPointer {
        advanced(by: Int(size))
    }
}

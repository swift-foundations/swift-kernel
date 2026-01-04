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

public import Formatting

extension Kernel.ByteCount {
    /// Formats this byte count to a human-readable string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Kernel.ByteCount.kilobyte.formatted(.bytes)           // "1.02 KB"
    /// Kernel.ByteCount.kilobyte.formatted(.bytes(.binary))  // "1 KiB"
    /// Kernel.ByteCount.megabyte.formatted(.bytes)           // "1.05 MB"
    /// ```
    ///
    /// - Parameter format: The byte format style to use.
    /// - Returns: A formatted string representation.
    @inlinable
    public func formatted(_ format: Format.Bytes) -> String {
        format.format(rawValue)
    }

    /// Formats this byte count using default byte formatting.
    ///
    /// Equivalent to `.formatted(.bytes)`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Kernel.ByteCount.megabyte.formatted()  // "1.05 MB"
    /// ```
    @inlinable
    public func formatted() -> String {
        formatted(.bytes)
    }
}

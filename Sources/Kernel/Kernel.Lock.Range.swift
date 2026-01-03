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

extension Kernel.Lock {
    /// The range of bytes to lock within a file.
    public enum Range: Sendable, Equatable, Hashable {
        /// Lock the entire file.
        case file

        /// Lock a specific byte range.
        ///
        /// - Parameters:
        ///   - start: The starting byte offset (inclusive).
        ///   - end: The ending byte offset (exclusive). Use `UInt64.max` to lock to EOF.
        ///
        /// This matches Swift's `Range<UInt64>` semantics (half-open interval).
        case bytes(start: UInt64, end: UInt64)

        /// Creates a byte range from a Swift Range.
        ///
        /// - Parameter range: The byte range to lock.
        @inlinable
        public init(_ range: Swift.Range<UInt64>) {
            self = .bytes(start: range.lowerBound, end: range.upperBound)
        }
    }
}

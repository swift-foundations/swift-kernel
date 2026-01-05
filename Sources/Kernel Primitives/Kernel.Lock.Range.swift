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
        ///   - end: The ending byte offset (exclusive). Use `.max` to lock to EOF.
        ///
        /// This matches Swift's `Range` semantics (half-open interval).
        case bytes(start: Kernel.File.Offset, end: Kernel.File.Offset)

        /// Creates a byte range from start to end offsets.
        ///
        /// - Parameters:
        ///   - start: The starting byte offset (inclusive).
        ///   - length: The number of bytes to lock.
        @inlinable
        public static func bytes(start: Kernel.File.Offset, length: Kernel.File.Size) -> Range {
            .bytes(start: start, end: start + length)
        }

        /// Creates a lock range suitable for a memory mapping.
        ///
        /// The range is rounded up to the platform's allocation granularity
        /// to ensure the lock covers every byte that could be faulted.
        ///
        /// - Parameters:
        ///   - offset: The aligned start offset of the mapping.
        ///   - length: The mapping length.
        @inlinable
        public init(
            forMappingAt offset: Kernel.File.Offset,
            length: Kernel.File.Size
        ) {
            let granularity = Kernel.System.allocationGranularity.alignment
            let endOffset = offset + length
            let roundedEnd = Kernel.System.alignUp(endOffset, to: granularity)
            self = .bytes(start: offset, end: roundedEnd)
        }
    }
}

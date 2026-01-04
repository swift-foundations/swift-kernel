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

#if canImport(Glibc) || canImport(Musl)

extension Kernel.IOUring {
    /// Index into a registered buffer array.
    ///
    /// Used with `IORING_OP_READ_FIXED` and `IORING_OP_WRITE_FIXED` to reference
    /// pre-registered buffers for zero-copy I/O.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// sqe.bufferIndex = BufferIndex(0)  // Use first registered buffer
    /// ```
    public struct BufferIndex: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt16

        /// Creates a buffer index from a raw value.
        @inlinable
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        /// Creates a buffer index from a UInt16 value.
        @inlinable
        public init(_ value: UInt16) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// First buffer in the registered array.
        public static let first = BufferIndex(0)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.IOUring.BufferIndex: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.IOUring.BufferIndex: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

#endif

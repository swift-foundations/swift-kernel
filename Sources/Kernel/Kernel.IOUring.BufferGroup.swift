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
    /// Buffer group identifier for automatic buffer selection.
    ///
    /// Used with `IOSQE_BUFFER_SELECT` flag to let the kernel select a buffer
    /// from a pre-registered pool. This enables efficient buffer management
    /// for operations where the buffer size isn't known in advance.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Register a buffer group
    /// let group = BufferGroup(1)
    ///
    /// // Use buffer selection in SQE
    /// sqe.flags |= IOSQE_BUFFER_SELECT
    /// sqe.bufferGroup = group
    /// ```
    public struct BufferGroup: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt16

        /// Creates a buffer group from a raw value.
        @inlinable
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        /// Creates a buffer group from a UInt16 value.
        @inlinable
        public init(_ value: UInt16) {
            self.rawValue = value
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.IOUring.BufferGroup: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt16) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.IOUring.BufferGroup: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

#endif

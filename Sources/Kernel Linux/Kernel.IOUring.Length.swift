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
public import Kernel_Primitives


#if canImport(Glibc) || canImport(Musl)

    extension Kernel.IOUring {
        /// Buffer length for io_uring operations.
        ///
        /// A type-safe wrapper for the 32-bit length field used in io_uring
        /// submission queue entries.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// // From a raw value
        /// let length = Kernel.IOUring.Length(rawValue: 4096)
        ///
        /// // From a File.Size
        /// let length = Kernel.IOUring.Length(fileSize)
        ///
        /// // From a buffer pointer
        /// let length = Kernel.IOUring.Length(buffer)
        /// ```
        public struct Length: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
            public let rawValue: UInt32

            /// Creates a length value.
            ///
            /// - Parameter rawValue: The 32-bit length value.
            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// Creates a length from an integer.
            ///
            /// Values larger than `UInt32.max` are clamped.
            ///
            /// - Parameter count: The length in bytes.
            @inlinable
            public init(_ count: Int) {
                self.rawValue = UInt32(clamping: count)
            }

            /// Creates a length from a buffer pointer.
            ///
            /// - Parameter buffer: The buffer whose count to use.
            @inlinable
            public init(_ buffer: UnsafeRawBufferPointer) {
                self.rawValue = UInt32(clamping: buffer.count)
            }

            /// Creates a length from a mutable buffer pointer.
            ///
            /// - Parameter buffer: The buffer whose count to use.
            @inlinable
            public init(_ buffer: UnsafeMutableRawBufferPointer) {
                self.rawValue = UInt32(clamping: buffer.count)
            }

            // MARK: - Common Values

            /// Zero length.
            public static let zero = Length(rawValue: 0)

            // MARK: - Comparable

            @inlinable
            public static func < (lhs: Length, rhs: Length) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    // MARK: - ExpressibleByIntegerLiteral

    extension Kernel.IOUring.Length: ExpressibleByIntegerLiteral {
        @inlinable
        public init(integerLiteral value: UInt32) {
            self.rawValue = value
        }
    }

    // MARK: - CustomStringConvertible

    extension Kernel.IOUring.Length: CustomStringConvertible {
        public var description: String {
            "\(rawValue)"
        }
    }

#endif

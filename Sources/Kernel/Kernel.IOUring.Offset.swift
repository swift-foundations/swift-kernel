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
        /// File offset for io_uring operations.
        ///
        /// Represents a file offset in io_uring's format, where `UInt64.max`
        /// indicates "use current file position".
        ///
        /// ## Usage
        ///
        /// ```swift
        /// // Read at a specific offset
        /// sqe.prepare.read(fd: fd, buffer: buf, length: len, offset: .zero, userData: id)
        ///
        /// // Read at current file position
        /// sqe.prepare.read(fd: fd, buffer: buf, length: len, offset: .current, userData: id)
        ///
        /// // Convert from Kernel.File.Offset
        /// let offset = Kernel.IOUring.Offset(fileOffset)
        /// ```
        public struct Offset: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
            public let rawValue: UInt64

            /// Creates an io_uring offset from a raw UInt64 value.
            @inlinable
            public init(rawValue: UInt64) {
                self.rawValue = rawValue
            }

            /// Creates an io_uring offset from an integer.
            @inlinable
            public init(_ value: UInt64) {
                self.rawValue = value
            }

            /// Creates an io_uring offset from a file offset.
            ///
            /// Negative file offsets (indicating "current position") are
            /// converted to `.current` (UInt64.max).
            @inlinable
            public init(_ fileOffset: Kernel.File.Offset) {
                if fileOffset.rawValue >= 0 {
                    self.rawValue = UInt64(bitPattern: fileOffset.rawValue)
                } else {
                    self.rawValue = UInt64.max
                }
            }

            // MARK: - Common Values

            /// Zero offset (beginning of file).
            public static let zero = Offset(rawValue: 0)

            /// Use current file position.
            ///
            /// When passed to read/write operations, the operation uses
            /// the file descriptor's current position.
            public static let current = Offset(rawValue: UInt64.max)

            // MARK: - Comparable

            @inlinable
            public static func < (lhs: Offset, rhs: Offset) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    // MARK: - ExpressibleByIntegerLiteral

    extension Kernel.IOUring.Offset: ExpressibleByIntegerLiteral {
        @inlinable
        public init(integerLiteral value: UInt64) {
            self.rawValue = value
        }
    }

    // MARK: - CustomStringConvertible

    extension Kernel.IOUring.Offset: CustomStringConvertible {
        public var description: String {
            if self == .current {
                return "current"
            }
            return "\(rawValue)"
        }
    }

#endif

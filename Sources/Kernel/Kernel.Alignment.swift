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

extension Kernel {
    /// Memory alignment value.
    ///
    /// A type-safe wrapper for alignment requirements. Alignment values
    /// must be powers of 2 (1, 2, 4, 8, 16, ...).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Common alignments
    /// let sector = Kernel.Alignment.bytes512
    /// let page = Kernel.Alignment.pageSize
    ///
    /// // Validated construction
    /// if let alignment = Kernel.Alignment(rawValue: 4096) {
    ///     // Valid power of 2
    /// }
    ///
    /// // Unchecked for known-valid values
    /// let alignment = Kernel.Alignment(unchecked: 512)
    /// ```
    public struct Alignment: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
        public let rawValue: Int

        /// Creates an alignment value, validating that it is a power of 2.
        ///
        /// - Parameter rawValue: The alignment value. Must be a positive power of 2.
        /// - Returns: `nil` if the value is not a valid alignment.
        @inlinable
        public init?(rawValue: Int) {
            guard rawValue > 0, rawValue & (rawValue - 1) == 0 else {
                return nil
            }
            self.rawValue = rawValue
        }

        /// Creates an alignment value without validation.
        ///
        /// - Parameter value: The alignment value. Must be a positive power of 2.
        /// - Precondition: `value` must be a positive power of 2.
        @inlinable
        public init(unchecked value: Int) {
            self.rawValue = value
        }

        // MARK: - Common Values

        /// 1-byte alignment (no alignment requirement).
        public static let bytes1 = Alignment(unchecked: 1)

        /// 2-byte alignment.
        public static let bytes2 = Alignment(unchecked: 2)

        /// 4-byte alignment.
        public static let bytes4 = Alignment(unchecked: 4)

        /// 8-byte alignment.
        public static let bytes8 = Alignment(unchecked: 8)

        /// 16-byte alignment (common SIMD alignment).
        public static let bytes16 = Alignment(unchecked: 16)

        /// 32-byte alignment (AVX alignment).
        public static let bytes32 = Alignment(unchecked: 32)

        /// 64-byte alignment (cache line on many architectures).
        public static let bytes64 = Alignment(unchecked: 64)

        /// 512-byte alignment (legacy sector size).
        public static let bytes512 = Alignment(unchecked: 512)

        /// 4096-byte alignment (common page size).
        public static let bytes4096 = Alignment(unchecked: 4096)

        /// 16384-byte alignment (Apple Silicon page size).
        public static let bytes16384 = Alignment(unchecked: 16384)

        /// System page size alignment.
        ///
        /// Computed from `Kernel.System.pageSize`.
        public static var pageSize: Alignment {
            Alignment(unchecked: Kernel.System.pageSize)
        }

        // MARK: - Comparable

        @inlinable
        public static func < (lhs: Alignment, rhs: Alignment) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        // MARK: - Validation

        /// Checks if a value is aligned to this alignment.
        ///
        /// - Parameter value: The value to check.
        /// - Returns: `true` if `value` is a multiple of this alignment.
        @inlinable
        public func isAligned(_ value: Int) -> Bool {
            value & (rawValue - 1) == 0
        }

        /// Checks if a value is aligned to this alignment.
        ///
        /// - Parameter value: The value to check.
        /// - Returns: `true` if `value` is a multiple of this alignment.
        @inlinable
        public func isAligned(_ value: Int64) -> Bool {
            value & Int64(rawValue - 1) == 0
        }

        /// Checks if a pointer is aligned to this alignment.
        ///
        /// - Parameter pointer: The pointer to check.
        /// - Returns: `true` if the pointer address is a multiple of this alignment.
        @inlinable
        public func isAligned(_ pointer: UnsafeRawPointer) -> Bool {
            Int(bitPattern: pointer) & (rawValue - 1) == 0
        }

        /// Rounds a value down to the nearest multiple of this alignment.
        ///
        /// - Parameter value: The value to align.
        /// - Returns: The largest multiple of this alignment ≤ `value`.
        @inlinable
        public func alignDown(_ value: Int) -> Int {
            value & ~(rawValue - 1)
        }

        /// Rounds a value up to the nearest multiple of this alignment.
        ///
        /// - Parameter value: The value to align.
        /// - Returns: The smallest multiple of this alignment ≥ `value`.
        @inlinable
        public func alignUp(_ value: Int) -> Int {
            (value + rawValue - 1) & ~(rawValue - 1)
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Alignment: CustomStringConvertible {
    public var description: String {
        if rawValue >= 1024 * 1024 {
            return "\(rawValue / (1024 * 1024))MB"
        } else if rawValue >= 1024 {
            return "\(rawValue / 1024)KB"
        } else {
            return "\(rawValue)B"
        }
    }
}

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
        /// User data associated with io_uring submission queue entries.
        ///
        /// User data is an opaque 64-bit value that the kernel returns unchanged
        /// in the corresponding completion queue entry. This is typically used
        /// to identify which operation completed.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// // Use as an operation identifier
        /// let userData = Kernel.IOUring.UserData(rawValue: operationId)
        ///
        /// // Use with pointer-based lookup
        /// let userData = Kernel.IOUring.UserData(pointer: contextPtr)
        /// ```
        public struct UserData: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: UInt64

            /// Creates a user data value.
            ///
            /// - Parameter rawValue: The 64-bit value to associate with an operation.
            @inlinable
            public init(rawValue: UInt64) {
                self.rawValue = rawValue
            }

            /// Creates a user data value from an integer identifier.
            ///
            /// - Parameter id: An integer identifier for the operation.
            @inlinable
            public init(_ id: UInt64) {
                self.rawValue = id
            }

            /// Creates a user data value from a pointer.
            ///
            /// This is useful when you want to associate a context object
            /// with an operation.
            ///
            /// - Parameter pointer: A pointer to associate with the operation.
            @inlinable
            public init<T>(pointer: UnsafePointer<T>) {
                self.rawValue = UInt64(UInt(bitPattern: pointer))
            }

            /// Creates a user data value from a mutable pointer.
            ///
            /// - Parameter pointer: A mutable pointer to associate with the operation.
            @inlinable
            public init<T>(pointer: UnsafeMutablePointer<T>) {
                self.rawValue = UInt64(UInt(bitPattern: pointer))
            }

            // MARK: - Common Values

            /// Zero user data.
            public static let zero = UserData(rawValue: 0)
        }
    }

    // MARK: - CustomStringConvertible

    extension Kernel.IOUring.UserData: CustomStringConvertible {
        public var description: String {
            "UserData(\(rawValue))"
        }
    }

#endif

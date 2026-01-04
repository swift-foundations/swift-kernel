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

extension Kernel.Event {
    /// Event source identifier.
    ///
    /// Identifies the source of an event, which may be a file descriptor,
    /// timer ID, signal number, or other platform-specific identifier.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // From a descriptor
    /// let id = Event.Identifier(descriptor: fd)
    ///
    /// // From a raw identifier
    /// let id = Event.Identifier(42)
    /// ```
    ///
    /// ## Platform Notes
    ///
    /// - **epoll**: File descriptor (`int`)
    /// - **kqueue**: Identifier type depends on filter (fd, pid, signal, etc.)
    /// - **io_uring**: File descriptor for most operations
    public struct Identifier: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt

        /// Creates an identifier from a raw value.
        @inlinable
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Creates an identifier from a UInt value.
        @inlinable
        public init(_ value: UInt) {
            self.rawValue = value
        }

        /// Creates an identifier from a file descriptor.
        @inlinable
        public init(descriptor: Kernel.Descriptor) {
            #if os(Windows)
            self.rawValue = UInt(bitPattern: descriptor.rawValue)
            #else
            self.rawValue = UInt(bitPattern: Int(descriptor.rawValue))
            #endif
        }

        /// Creates an identifier from a socket descriptor.
        @inlinable
        public init(socket: Kernel.Socket.Descriptor) {
            #if os(Windows)
            self.rawValue = UInt(socket.rawValue)
            #else
            self.rawValue = UInt(bitPattern: Int(socket.rawValue))
            #endif
        }

        /// Creates an identifier from an Int32 (for signals, etc.).
        @inlinable
        public init(_ value: Int32) {
            self.rawValue = UInt(bitPattern: Int(value))
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.Event.Identifier: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Event.Identifier: CustomStringConvertible {
    public var description: String {
        "\(rawValue)"
    }
}

// MARK: - Descriptor Conversion

extension Kernel.Event.Identifier {
    /// Returns this identifier as a file descriptor, if valid.
    ///
    /// - Returns: A Kernel.Descriptor if the value fits in Int32.
    @inlinable
    public var asDescriptor: Kernel.Descriptor? {
        #if os(Windows)
        return Kernel.Descriptor(rawValue: HANDLE(bitPattern: Int(rawValue)))
        #else
        guard rawValue <= UInt(Int32.max) else { return nil }
        return Kernel.Descriptor(rawValue: Int32(rawValue))
        #endif
    }
}

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

public import Kernel

extension Kernel.Event {
    /// Test utilities for eventing operations (kqueue, epoll, io_uring).
    public enum Test {
        /// Error thrown when pipe creation fails.
        public struct PipeError: Swift.Error, Sendable {
            public init() {}
        }

        /// Creates a pipe, returning ~Copyable `Pipe.Descriptors`.
        ///
        /// - Returns: The pipe descriptors (read + write).
        /// - Throws: `PipeError` if pipe creation fails
        public static func makePipe() throws -> Kernel.Pipe.Descriptors {
            do {
                return try Kernel.Pipe.pipe()
            } catch {
                throw PipeError()
            }
        }

        /// Closes a descriptor without throwing (safe for defer blocks).
        ///
        /// - Parameter fd: The descriptor to close
        public static func closeNoThrow(_ fd: borrowing Kernel.Descriptor) {
            try? Kernel.Close.close(fd)
        }

        /// Writes one byte to a descriptor.
        ///
        /// - Parameters:
        ///   - fd: The descriptor to write to
        ///   - value: The byte value to write (default: 1)
        public static func writeByte(_ fd: borrowing Kernel.Descriptor, value: UInt8 = 1) {
            var byte = value
            _ = unsafe withUnsafeBytes(of: &byte) { buffer in
                try? unsafe Kernel.IO.Write.write(fd, from: buffer)
            }
        }

        /// Drains one byte from a descriptor.
        ///
        /// - Parameter fd: The descriptor to read from
        public static func readDrain(_ fd: borrowing Kernel.Descriptor) {
            var byte: UInt8 = 0
            _ = unsafe withUnsafeMutableBytes(of: &byte) { buffer in
                try? unsafe Kernel.IO.Read.read(fd, into: buffer)
            }
        }
    }
}

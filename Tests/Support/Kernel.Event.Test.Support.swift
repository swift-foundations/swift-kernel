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

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

extension Kernel.Event {
    /// Test utilities for eventing operations (kqueue, epoll, io_uring).
    public enum Test {
        /// Error thrown when pipe creation fails.
        public struct PipeError: Swift.Error, Sendable {
            public init() {}
        }

        /// Creates a pipe, returning (read, write) descriptors.
        ///
        /// - Returns: Tuple of (read descriptor, write descriptor)
        /// - Throws: `PipeError` if pipe creation fails
        public static func makePipe() throws -> (read: Kernel.Descriptor, write: Kernel.Descriptor) {
            var fds: [Int32] = [0, 0]
            guard pipe(&fds) == 0 else { throw PipeError() }
            return (Kernel.Descriptor(rawValue: fds[0]), Kernel.Descriptor(rawValue: fds[1]))
        }

        /// Closes a descriptor without throwing (safe for defer blocks).
        ///
        /// - Parameter fd: The descriptor to close
        public static func closeNoThrow(_ fd: Kernel.Descriptor) {
            _ = close(fd.rawValue)
        }

        /// Writes one byte to a descriptor.
        ///
        /// - Parameters:
        ///   - fd: The descriptor to write to
        ///   - value: The byte value to write (default: 1)
        public static func writeByte(_ fd: Kernel.Descriptor, value: UInt8 = 1) {
            var byte = value
            _ = write(fd.rawValue, &byte, 1)
        }

        /// Drains one byte from a descriptor.
        ///
        /// - Parameter fd: The descriptor to read from
        public static func readDrain(_ fd: Kernel.Descriptor) {
            var byte: UInt8 = 0
            _ = read(fd.rawValue, &byte, 1)
        }
    }
}

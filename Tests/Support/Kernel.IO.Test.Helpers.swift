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

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

#if !os(Windows)

    public import Kernel_Primitives

    /// Test utilities for I/O operations.
    public enum KernelIOTest {
        /// Error thrown when temp file creation fails.
        public struct TempFileError: Swift.Error, Sendable {
            public init() {}
        }

        /// Creates a temporary file and returns its path and descriptor.
        ///
        /// - Parameter prefix: Prefix for the temp file name (default: "io-test")
        /// - Returns: Tuple of (path, descriptor)
        /// - Throws: `TempFileError` if creation fails
        public static func createTempFile(
            prefix: String = "io-test"
        ) throws -> (path: String, fd: Kernel.Descriptor) {
            let tmpdir = getenv("TMPDIR").map { String(cString: $0) } ?? "/tmp"
            let template = "\(tmpdir)/\(prefix)-XXXXXX"
            var templateBytes = Array(template.utf8) + [0]

            let fd = templateBytes.withUnsafeMutableBufferPointer { buffer in
                mkstemp(buffer.baseAddress!)
            }
            guard fd >= 0 else {
                throw TempFileError()
            }

            let path = String(decoding: templateBytes.dropLast(), as: UTF8.self)
            return (path, Kernel.Descriptor(rawValue: fd))
        }

        /// Creates a temporary file with initial content.
        ///
        /// - Parameters:
        ///   - content: The string content to write
        ///   - prefix: Prefix for the temp file name (default: "io-test")
        /// - Returns: Tuple of (path, descriptor)
        /// - Throws: `TempFileError` if creation fails
        public static func createTempFileWithContent(
            _ content: String,
            prefix: String = "io-test"
        ) throws -> (path: String, fd: Kernel.Descriptor) {
            let (path, fd) = try createTempFile(prefix: prefix)

            var contentBytes = Array(content.utf8)
            _ = contentBytes.withUnsafeMutableBytes { ptr in
                write(fd.rawValue, ptr.baseAddress, ptr.count)
            }

            return (path, fd)
        }

        /// Creates a temporary file with initial content (for File.Handle tests).
        ///
        /// - Parameters:
        ///   - content: The string content to write
        ///   - prefix: Prefix for the temp file name (default: "io-test")
        /// - Returns: Tuple of (path, File.Descriptor)
        /// - Throws: `TempFileError` if creation fails
        public static func createTempFileForHandle(
            _ content: String? = nil,
            prefix: String = "handle-test"
        ) throws -> (path: String, fd: Kernel.File.Descriptor) {
            let tmpdir = getenv("TMPDIR").map { String(cString: $0) } ?? "/tmp"
            let template = "\(tmpdir)/\(prefix)-XXXXXX"
            var templateBytes = Array(template.utf8) + [0]

            let fd = templateBytes.withUnsafeMutableBufferPointer { buffer in
                mkstemp(buffer.baseAddress!)
            }
            guard fd >= 0 else {
                throw TempFileError()
            }

            if let content = content {
                var contentBytes = Array(content.utf8)
                _ = contentBytes.withUnsafeMutableBytes { ptr in
                    write(fd, ptr.baseAddress, ptr.count)
                }
            }

            let path = String(decoding: templateBytes.dropLast(), as: UTF8.self)
            return (path, Kernel.File.Descriptor(rawValue: fd))
        }

        /// Cleans up a temporary file.
        ///
        /// - Parameters:
        ///   - path: The file path to unlink
        ///   - fd: The descriptor to close
        public static func cleanupTempFile(path: String, fd: Kernel.Descriptor) {
            close(fd.rawValue)
            unlink(path)
        }
    }

#endif

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

import SystemPackage

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
        ) throws -> (path: FilePath, fd: Kernel.Descriptor) {
            let path = Kernel.Temporary.filePath(prefix: prefix)
            do {
                let fd = try Kernel.File.Open.open(
                    path: path,
                    mode: [.read, .write],
                    options: [.create, .truncate, .exclusive],
                    permissions: 0o600
                )
                return (path, fd)
            } catch {
                throw TempFileError()
            }
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
        ) throws -> (path: FilePath, fd: Kernel.Descriptor) {
            let (path, fd) = try createTempFile(prefix: prefix)

            var contentBytes = Array(content.utf8)
            _ = try? contentBytes.withUnsafeMutableBytes { ptr in
                try Kernel.IO.Write.write(fd, from: UnsafeRawBufferPointer(ptr))
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
        ) throws -> (path: FilePath, fd: Kernel.File.Descriptor) {
            let path = Kernel.Temporary.filePath(prefix: prefix)
            do {
                let fd = try Kernel.File.Open.open(
                    path: path,
                    mode: [.read, .write],
                    options: [.create, .truncate, .exclusive],
                    permissions: 0o600
                )

                if let content = content {
                    var contentBytes = Array(content.utf8)
                    _ = try? contentBytes.withUnsafeMutableBytes { ptr in
                        try Kernel.IO.Write.write(fd, from: UnsafeRawBufferPointer(ptr))
                    }
                }

                return (path, Kernel.File.Descriptor(rawValue: fd.rawValue))
            } catch {
                throw TempFileError()
            }
        }

        /// Cleans up a temporary file.
        ///
        /// - Parameters:
        ///   - path: The file path to unlink
        ///   - fd: The descriptor to close
        public static func cleanupTempFile(path: FilePath, fd: Kernel.Descriptor) {
            try? Kernel.Close.close(fd)
            try? Kernel.Unlink.unlink(path)
        }
    }

#endif

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

#if !os(Windows)

    public import Kernel

    /// Test utilities for I/O operations.
    public enum KernelIOTest {
        /// Error thrown when temp file creation fails.
        public struct TempFileError: Swift.Error, Sendable {
            public init() {}
        }

        /// ~Copyable temp file handle returned from `createTempFile`.
        /// Owns the `Kernel.Descriptor`.
        public struct TempFile: ~Copyable, Sendable {
            public let path: Swift.String
            public let descriptor: Kernel.Descriptor

            public init(path: Swift.String, descriptor: consuming Kernel.Descriptor) {
                self.path = path
                self.descriptor = descriptor
            }
        }

        // MARK: - Direct helpers (open + defer close pattern)

        /// Creates a temporary file and returns a ~Copyable TempFile.
        /// Caller is responsible for cleanup via `cleanupTempFile`.
        public static func createTempFile(prefix: Swift.String = "io-test") throws -> TempFile {
            let pathString = Kernel.Temporary.filePath(prefix: prefix)
            let fd = try Kernel.Path.scope(pathString) { path in
                try Kernel.File.Open.open(
                    path: path,
                    mode: .readWrite,
                    options: [.create, .truncate, .exclusive],
                    permissions: .ownerReadWrite
                )
            }
            return TempFile(path: pathString, descriptor: fd)
        }

        /// Creates a temporary file with content and returns a ~Copyable TempFile.
        /// Caller is responsible for cleanup via `cleanupTempFile`.
        public static func createTempFileWithContent(_ content: Swift.String, prefix: Swift.String = "io-test") throws -> TempFile {
            let tempFile = try createTempFile(prefix: prefix)
            var contentBytes = Array(content.utf8)
            _ = try? unsafe contentBytes.withUnsafeMutableBytes { ptr in
                try unsafe Kernel.IO.Write.write(tempFile.descriptor, from: UnsafeRawBufferPointer(ptr))
            }
            return tempFile
        }

        /// Cleans up a temporary file.
        public static func cleanupTempFile(_ tempFile: borrowing TempFile) {
            try? Kernel.Close.close(tempFile.descriptor)
            try? Kernel.Path.scope(tempFile.path) { p in
                try Kernel.File.Delete.delete(p)
            }
        }

        // MARK: - Closure-based helpers (preferred)

        /// Creates a temporary file and executes the body with path and descriptor.
        ///
        /// The file is automatically cleaned up after the body completes.
        public static func withTempFile<R>(
            prefix: Swift.String = "io-test",
            _ body: (borrowing Kernel.Path.View, borrowing Kernel.Descriptor) throws -> R
        ) throws -> R {
            let pathString = Kernel.Temporary.filePath(prefix: prefix)
            return try Kernel.Path.scope(pathString) { path in
                // Open directly — avoid do-catch assignment of ~Copyable (compiler bug).
                let fd = try Kernel.File.Open.open(
                    path: path,
                    mode: .readWrite,
                    options: [.create, .truncate, .exclusive],
                    permissions: .ownerReadWrite
                )
                defer {
                    try? Kernel.Close.close(fd)
                    try? Kernel.File.Delete.delete(path)
                }
                return try body(path, fd)
            }
        }

        /// Creates a temporary file with initial content and executes the body.
        public static func withTempFile<R>(
            content: Swift.String,
            prefix: Swift.String = "io-test",
            _ body: (borrowing Kernel.Path.View, borrowing Kernel.Descriptor) throws -> R
        ) throws -> R {
            try withTempFile(prefix: prefix) { path, fd in
                var contentBytes = Array(content.utf8)
                _ = try? unsafe contentBytes.withUnsafeMutableBytes { ptr in
                    try unsafe Kernel.IO.Write.write(fd, from: UnsafeRawBufferPointer(ptr))
                }
                return try body(path, fd)
            }
        }

        /// Creates a temporary file for Handle tests and executes the body.
        public static func withTempFileForHandle<R>(
            content: Swift.String? = nil,
            prefix: Swift.String = "handle-test",
            _ body: (borrowing Kernel.Path.View, borrowing Kernel.File.Descriptor) throws -> R
        ) throws -> R {
            let pathString = Kernel.Temporary.filePath(prefix: prefix)
            return try Kernel.Path.scope(pathString) { path in
                // Open directly — avoid do-catch assignment of ~Copyable (compiler bug).
                let fd = try Kernel.File.Open.open(
                    path: path,
                    mode: .readWrite,
                    options: [.create, .truncate, .exclusive],
                    permissions: .ownerReadWrite
                )

                if let content = content {
                    var contentBytes = Array(content.utf8)
                    _ = try? unsafe contentBytes.withUnsafeMutableBytes { ptr in
                        try unsafe Kernel.IO.Write.write(fd, from: UnsafeRawBufferPointer(ptr))
                    }
                }

                defer {
                    try? Kernel.Close.close(fd)
                    try? Kernel.File.Delete.delete(path)
                }

                return try body(path, fd)
            }
        }
    }

#endif

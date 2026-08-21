#if !os(Windows)

    public import Kernel

    public enum KernelIOTest {

        public struct TempFileError: Swift.Error, Sendable {
            public init() {}
        }

        public struct TempFile: ~Copyable, Sendable {
            public let path: Swift.String
            public let descriptor: Kernel.Descriptor

            public init(path: Swift.String, descriptor: consuming Kernel.Descriptor) {
                self.path = path
                self.descriptor = descriptor
            }
        }

        public static func createTempFile(prefix: Swift.String = "io-test") throws -> TempFile {
            let pathString = Kernel.Temporary.filePath(prefix: prefix)
            let fd = try Path.scope(pathString) { path in
                try Kernel.File.Open.open(
                    path: path,
                    mode: .readWrite,
                    options: [.create, .truncate, .exclusive],
                    permissions: .ownerReadWrite
                )
            }
            return TempFile(path: pathString, descriptor: fd)
        }

        public static func createTempFileWithContent(_ content: Swift.String, prefix: Swift.String = "io-test") throws -> TempFile {
            let tempFile = try createTempFile(prefix: prefix)
            var contentBytes = Array(content.utf8)
            _ = try? contentBytes.withUnsafeMutableBytes { ptr in
                try unsafe POSIX.Kernel.IO.Write.write(tempFile.descriptor, from: UnsafeRawBufferPointer(ptr))
            }
            return tempFile
        }

        public static func cleanupTempFile(_ tempFile: borrowing TempFile) {
            try? Path.scope(tempFile.path) { p in
                try Kernel.File.Delete.delete(p)
            }
        }

        public static func withTempFile<R>(
            prefix: Swift.String = "io-test",
            _ body: (borrowing Path.Borrowed, borrowing Kernel.Descriptor) throws -> R
        ) throws -> R {
            let pathString = Kernel.Temporary.filePath(prefix: prefix)
            return try Path.scope(pathString) { path in
                let fd = try Kernel.File.Open.open(
                    path: path,
                    mode: .readWrite,
                    options: [.create, .truncate, .exclusive],
                    permissions: .ownerReadWrite
                )
                defer {

                    try? Kernel.File.Delete.delete(path)
                }
                return try body(path, fd)
            }
        }

        public static func withTempFile<R>(
            content: Swift.String,
            prefix: Swift.String = "io-test",
            _ body: (borrowing Path.Borrowed, borrowing Kernel.Descriptor) throws -> R
        ) throws -> R {
            try withTempFile(prefix: prefix) { path, fd in
                var contentBytes = Array(content.utf8)
                _ = try? contentBytes.withUnsafeMutableBytes { ptr in
                    try unsafe POSIX.Kernel.IO.Write.write(fd, from: UnsafeRawBufferPointer(ptr))
                }
                return try body(path, fd)
            }
        }

        public static func withTempFileForHandle<R>(
            content: Swift.String? = nil,
            prefix: Swift.String = "handle-test",
            _ body: (borrowing Path.Borrowed, borrowing Kernel.File.Descriptor) throws -> R
        ) throws -> R {
            let pathString = Kernel.Temporary.filePath(prefix: prefix)
            return try Path.scope(pathString) { path in
                let fd = try Kernel.File.Open.open(
                    path: path,
                    mode: .readWrite,
                    options: [.create, .truncate, .exclusive],
                    permissions: .ownerReadWrite
                )

                if let content {
                    var contentBytes = Array(content.utf8)
                    _ = try? contentBytes.withUnsafeMutableBytes { ptr in
                        try unsafe POSIX.Kernel.IO.Write.write(fd, from: UnsafeRawBufferPointer(ptr))
                    }
                }

                defer {

                    try? Kernel.File.Delete.delete(path)
                }

                return try body(path, fd)
            }
        }
    }

#endif

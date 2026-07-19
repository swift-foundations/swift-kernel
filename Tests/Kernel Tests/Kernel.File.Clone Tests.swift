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

import Kernel
import Kernel_Test_Support
import Testing

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

// MARK: - Cross-Platform Test Helpers

#if !os(Windows)
    /// Creates a temporary file with content and returns its path
    private func createTempFile(prefix: Swift.String, content: Swift.String) -> Swift.String {
        let path = "/tmp/\(prefix)-\(getpid())-\(Int.random(in: 0..<Int.max))"
        let fd = open(path, O_CREAT | O_WRONLY, 0o644)
        guard fd >= 0 else { return path }
        defer { close(fd) }

        _ = content.withCString { ptr in
            write(fd, ptr, content.count)
        }

        return path
    }

    /// Reads content from a file
    private func readFileContent(_ path: Swift.String) -> Swift.String? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count - 1)
        guard bytesRead > 0 else { return nil }

        return Swift.String(cString: buffer)
    }

    /// Cleans up a temp file
    private func cleanup(_ path: Swift.String) {
        _ = path.withCString { unlink($0) }
    }
#endif

@Suite
struct Test {

    // MARK: - Type Tests

    @Suite
    struct Test {

        @Test
        func `Capability enum values`() {
            let reflink = Kernel.File.Clone.Capability.reflink
            let none = Kernel.File.Clone.Capability.none

            #expect(reflink != none)
            #expect(reflink == .reflink)
            #expect(none == .none)
        }

        @Test
        func `Behavior enum values`() {
            let reflinkOrFail = Kernel.File.Clone.Behavior.reflinkOrFail
            let reflinkOrCopy = Kernel.File.Clone.Behavior.reflinkOrCopy
            let copyOnly = Kernel.File.Clone.Behavior.copyOnly

            #expect(reflinkOrFail != reflinkOrCopy)
            #expect(reflinkOrCopy != copyOnly)
            #expect(reflinkOrFail != copyOnly)
        }

        @Test
        func `Result enum values`() {
            let reflinked = Kernel.File.Clone.Result.reflinked
            let copied = Kernel.File.Clone.Result.copied

            #expect(reflinked != copied)
        }

        @Test
        func `types are Sendable`() {
            let cap: Kernel.File.Clone.Capability = .reflink
            let behavior: Kernel.File.Clone.Behavior = .reflinkOrCopy
            let result: Kernel.File.Clone.Result = .copied

            Task.detached {
                _ = cap
                _ = behavior
                _ = result
            }
        }
    }

    // MARK: - Error Tests

    @Suite
    struct Test {

        @Test
        func `error descriptions are meaningful`() {
            let errors: [Kernel.File.Clone.Error] = [
                .notSupported,
                .crossDevice,
                .sourceNotFound,
                .destinationExists,
                .permissionDenied,
                .isDirectory,
                .platform(code: .posix(42), operation: .copy),
            ]

            for error in errors {
                let description = error.description
                #expect(!description.isEmpty)
            }

            #expect(Kernel.File.Clone.Error.notSupported.description.contains("not supported"))
            #expect(Kernel.File.Clone.Error.crossDevice.description.contains("different"))
        }

        @Test
        func `error is Equatable`() {
            #expect(Kernel.File.Clone.Error.notSupported == .notSupported)
            #expect(Kernel.File.Clone.Error.crossDevice != .notSupported)

            let p1 = Kernel.File.Clone.Error.platform(code: .posix(1), operation: .copy)
            let p2 = Kernel.File.Clone.Error.platform(code: .posix(1), operation: .copy)
            let p3 = Kernel.File.Clone.Error.platform(code: .posix(2), operation: .copy)

            #expect(p1 == p2)
            #expect(p1 != p3)
        }
    }

    // MARK: - Capability Probing Tests

    #if os(macOS)
        @Suite
        struct Test {

            @Test
            func `probe capability returns valid result`() throws {
                // Probe /tmp which is on the boot volume (typically APFS)
                let cap = try Path.scope("/tmp") { path in
                    try Kernel.File.Clone.Capability.probe(at: path)
                }

                // On modern macOS with APFS, should be .reflink
                // On older systems or HFS+, would be .none
                #expect(cap == .reflink || cap == .none)
            }

            @Test
            func `probe nonexistent path throws`() {
                typealias E = Path.String.Error<Kernel.File.Clone.Error.Syscall>

                expectThrows(
                    { (error: E) in
                        #expect(error.body != nil)
                    },
                    { () throws(E) in
                        _ = try Path.scope("/nonexistent/path/that/does/not/exist") {
                            (path) throws(Kernel.File.Clone.Error.Syscall) in
                            try Kernel.File.Clone.Capability.probe(at: path)
                        }
                    }
                )
            }
        }
    #endif

    // MARK: - Clone Operation Tests

    #if !os(Windows)
        @Suite
        struct Test {

            @Test
            func `copyOnly creates independent copy`() throws {
                let content = "Hello, World! This is test content for cloning."
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = "/tmp/clone-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Path.scope(source) { srcPath in
                    try Path.scope(dest) { dstPath in
                        try Kernel.File.Clone.clone(
                            from: srcPath,
                            to: dstPath,
                            behavior: .copyOnly
                        )
                    }
                }

                #expect(result == .copied)

                // Verify content matches
                let readContent = readFileContent(dest)
                #expect(readContent == content)
            }

            @Test
            func `reflinkOrCopy succeeds on APFS`() throws {
                let content = "Test content for reflink or copy"
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = "/tmp/clone-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Path.scope(source) { srcPath in
                    try Path.scope(dest) { dstPath in
                        try Kernel.File.Clone.clone(
                            from: srcPath,
                            to: dstPath,
                            behavior: .reflinkOrCopy
                        )
                    }
                }

                // Should succeed either way
                #expect(result == .reflinked || result == .copied)

                // Verify content matches
                let readContent = readFileContent(dest)
                #expect(readContent == content)
            }

            @Test
            func `reflinkOrFail on APFS returns reflinked`() throws {
                let content = "Test content for reflink only"
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = "/tmp/clone-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                try Path.scope(source) { srcPath in
                    try Path.scope(dest) { dstPath in
                        // First check capability
                        let cap = try Kernel.File.Clone.Capability.probe(at: srcPath)

                        if cap == .reflink {
                            let result = try Kernel.File.Clone.clone(
                                from: srcPath,
                                to: dstPath,
                                behavior: .reflinkOrFail
                            )
                            #expect(result == .reflinked)
                        } else {
                            // If filesystem doesn't support reflink, should throw
                            #expect(throws: Kernel.File.Clone.Error.notSupported) {
                                try Kernel.File.Clone.clone(
                                    from: srcPath,
                                    to: dstPath,
                                    behavior: .reflinkOrFail
                                )
                            }
                        }
                    }
                }
            }

            @Test
            func `clone to existing destination fails`() throws {
                let content = "Source content"
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = createTempFile(prefix: "clone-dst", content: "Existing")

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                typealias E = Path.String.Error<Kernel.File.Clone.Error>

                expectThrows(
                    { (error: E) in
                        #expect(error.body == .destinationExists)
                    },
                    { () throws(E) in
                        _ = try Path.scope(source, dest) {
                            (srcPath, dstPath) throws(Kernel.File.Clone.Error) in
                            try Kernel.File.Clone.clone(
                                from: srcPath,
                                to: dstPath,
                                behavior: .copyOnly
                            )
                        }
                    }
                )
            }

            @Test
            func `clone from nonexistent source fails`() {
                let source = "/tmp/nonexistent-\(getpid())"
                let dest = "/tmp/clone-dst-\(getpid())"

                typealias E = Path.String.Error<Kernel.File.Clone.Error>

                expectThrows(
                    { (error: E) in
                        #expect(error.body == .sourceNotFound)
                    },
                    { () throws(E) in
                        _ = try Path.scope(source, dest) {
                            (srcPath, dstPath) throws(Kernel.File.Clone.Error) in
                            try Kernel.File.Clone.clone(
                                from: srcPath,
                                to: dstPath,
                                behavior: .copyOnly
                            )
                        }
                    }
                )
            }

            @Test
            func `clone large file`() throws {
                // Create a 1MB file
                let size = 1024 * 1024
                let content = Swift.String(repeating: "X", count: size)
                let source = createTempFile(prefix: "clone-large-src", content: content)
                let dest = "/tmp/clone-large-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Path.scope(source) { srcPath in
                    try Path.scope(dest) { dstPath in
                        try Kernel.File.Clone.clone(
                            from: srcPath,
                            to: dstPath,
                            behavior: .reflinkOrCopy
                        )
                    }
                }

                #expect(result == .reflinked || result == .copied)

                // Verify size by reading
                var statBuf = stat()
                let statResult = dest.withCString { stat($0, &statBuf) }
                #expect(statResult == 0)
                #expect(Int(statBuf.st_size) == size)
            }

            @Test
            func `clone empty file`() throws {
                let source = createTempFile(prefix: "clone-empty-src", content: "")
                let dest = "/tmp/clone-empty-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Path.scope(source) { srcPath in
                    try Path.scope(dest) { dstPath in
                        try Kernel.File.Clone.clone(
                            from: srcPath,
                            to: dstPath,
                            behavior: .copyOnly
                        )
                    }
                }

                #expect(result == .copied)

                // Verify destination exists and is empty
                var statBuf = stat()
                let statResult = dest.withCString { stat($0, &statBuf) }
                #expect(statResult == 0)
                #expect(statBuf.st_size == 0)
            }
        }
    #endif
}

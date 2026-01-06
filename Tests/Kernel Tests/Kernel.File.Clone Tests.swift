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
import Kernel_Primitives
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
    private func createTempFile(prefix: String, content: String) -> String {
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
    private func readFileContent(_ path: String) -> String? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count - 1)
        guard bytesRead > 0 else { return nil }

        return String(cString: buffer)
    }

    /// Cleans up a temp file
    private func cleanup(_ path: String) {
        _ = path.withCString { unlink($0) }
    }
#endif

@Suite("Kernel.File.Clone")
struct KernelFileCloneTests {

    // MARK: - Type Tests

    @Suite("Types")
    struct TypeTests {

        @Test("Capability enum values")
        func capabilityValues() {
            let reflink = Kernel.File.Clone.Capability.reflink
            let none = Kernel.File.Clone.Capability.none

            #expect(reflink != none)
            #expect(reflink == .reflink)
            #expect(none == .none)
        }

        @Test("Behavior enum values")
        func behaviorValues() {
            let reflinkOrFail = Kernel.File.Clone.Behavior.reflinkOrFail
            let reflinkOrCopy = Kernel.File.Clone.Behavior.reflinkOrCopy
            let copyOnly = Kernel.File.Clone.Behavior.copyOnly

            #expect(reflinkOrFail != reflinkOrCopy)
            #expect(reflinkOrCopy != copyOnly)
            #expect(reflinkOrFail != copyOnly)
        }

        @Test("Result enum values")
        func resultValues() {
            let reflinked = Kernel.File.Clone.Result.reflinked
            let copied = Kernel.File.Clone.Result.copied

            #expect(reflinked != copied)
        }

        @Test("types are Sendable")
        func typesAreSendable() {
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

    @Suite("Error")
    struct ErrorTests {

        @Test("error descriptions are meaningful")
        func errorDescriptions() {
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

        @Test("error is Equatable")
        func errorEquatable() {
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
        @Suite("Capability Probing")
        struct CapabilityProbingTests {

            @Test("probe capability returns valid result")
            func probeCapability() throws {
                // Probe /tmp which is on the boot volume (typically APFS)
                let cap = try Kernel.Path.scope("/tmp") { path in
                    try Kernel.File.Clone.Capability.probe(at: path)
                }

                // On modern macOS with APFS, should be .reflink
                // On older systems or HFS+, would be .none
                #expect(cap == .reflink || cap == .none)
            }

            @Test("probe nonexistent path throws")
            func probeNonexistent() {
                typealias E = Kernel.Path.String.Error<Kernel.File.Clone.Error.Syscall>

                expectThrows({ (error: E) in
                    #expect(error.body != nil)
                }, { () throws(E) in
                    _ = try Kernel.Path.scope("/nonexistent/path/that/does/not/exist") {
                        (path) throws(Kernel.File.Clone.Error.Syscall) in
                        try Kernel.File.Clone.Capability.probe(at: path)
                    }
                })
            }
        }
    #endif

    // MARK: - Clone Operation Tests

    #if !os(Windows)
        @Suite("Clone Operations")
        struct CloneOperationTests {

            @Test("copyOnly creates independent copy")
            func copyOnlyCreatesIndependentCopy() throws {
                let content = "Hello, World! This is test content for cloning."
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = "/tmp/clone-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Kernel.Path.scope(source) { srcPath in
                    try Kernel.Path.scope(dest) { dstPath in
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

            @Test("reflinkOrCopy succeeds on APFS")
            func reflinkOrCopySucceeds() throws {
                let content = "Test content for reflink or copy"
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = "/tmp/clone-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Kernel.Path.scope(source) { srcPath in
                    try Kernel.Path.scope(dest) { dstPath in
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

            @Test("reflinkOrFail on APFS returns reflinked")
            func reflinkOrFailOnAPFS() throws {
                let content = "Test content for reflink only"
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = "/tmp/clone-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                try Kernel.Path.scope(source) { srcPath in
                    try Kernel.Path.scope(dest) { dstPath in
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

            @Test("clone to existing destination fails")
            func cloneToExistingFails() throws {
                let content = "Source content"
                let source = createTempFile(prefix: "clone-src", content: content)
                let dest = createTempFile(prefix: "clone-dst", content: "Existing")

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                typealias E = Kernel.Path.String.Error<Kernel.File.Clone.Error>

                expectThrows({ (error: E) in
                    #expect(error.body == .destinationExists)
                }, { () throws(E) in
                    _ = try Kernel.Path.scope(source, dest) {
                        (srcPath, dstPath) throws(Kernel.File.Clone.Error) in
                        try Kernel.File.Clone.clone(
                            from: srcPath,
                            to: dstPath,
                            behavior: .copyOnly
                        )
                    }
                })
            }

            @Test("clone from nonexistent source fails")
            func cloneFromNonexistentFails() {
                let source = "/tmp/nonexistent-\(getpid())"
                let dest = "/tmp/clone-dst-\(getpid())"

                typealias E = Kernel.Path.String.Error<Kernel.File.Clone.Error>

                expectThrows({ (error: E) in
                    #expect(error.body == .sourceNotFound)
                }, { () throws(E) in
                    _ = try Kernel.Path.scope(source, dest) {
                        (srcPath, dstPath) throws(Kernel.File.Clone.Error) in
                        try Kernel.File.Clone.clone(
                            from: srcPath,
                            to: dstPath,
                            behavior: .copyOnly
                        )
                    }
                })
            }

            @Test("clone large file")
            func cloneLargeFile() throws {
                // Create a 1MB file
                let size = 1024 * 1024
                let content = String(repeating: "X", count: size)
                let source = createTempFile(prefix: "clone-large-src", content: content)
                let dest = "/tmp/clone-large-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Kernel.Path.scope(source) { srcPath in
                    try Kernel.Path.scope(dest) { dstPath in
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

            @Test("clone empty file")
            func cloneEmptyFile() throws {
                let source = createTempFile(prefix: "clone-empty-src", content: "")
                let dest = "/tmp/clone-empty-dst-\(getpid())-\(Int.random(in: 0..<Int.max))"

                defer {
                    cleanup(source)
                    cleanup(dest)
                }

                let result = try Kernel.Path.scope(source) { srcPath in
                    try Kernel.Path.scope(dest) { dstPath in
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

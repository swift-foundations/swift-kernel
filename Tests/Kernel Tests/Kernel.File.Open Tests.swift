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
import Testing

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

// MARK: - Test Helpers

#if !os(Windows)
    /// Creates a temporary file with content and returns its path
    private func makeTempFile(prefix: Swift.String, content: Swift.String) -> Swift.String {
        let path = "/tmp/\(prefix)-\(getpid())-\(Int.random(in: 0..<Int.max))"
        let fd = open(path, O_CREAT | O_WRONLY, 0o644)
        guard fd >= 0 else { return path }
        defer { close(fd) }

        _ = content.withCString { ptr in
            write(fd, ptr, content.count)
        }

        return path
    }

    /// Cleans up a temp file
    private func removeTempFile(_ path: Swift.String) {
        _ = path.withCString { unlink($0) }
    }
#endif

// MARK: - Kernel.File.Open.Configuration Tests

@Suite("Kernel.File.Open.Configuration")
struct FileOpenConfigurationTests {

    @Test("default configuration")
    func defaultConfiguration() {
        let config = Kernel.File.Open.Configuration()

        #expect(config.mode == .read)
        #expect(config.create == false)
        #expect(config.truncate == false)
        #expect(config.cache == .buffered)
    }

    @Test("configuration with mode")
    func configurationWithMode() {
        let readConfig = Kernel.File.Open.Configuration(mode: .read)
        let writeConfig = Kernel.File.Open.Configuration(mode: .write)
        let readWriteConfig = Kernel.File.Open.Configuration(mode: .readWrite)

        #expect(readConfig.mode == .read)
        #expect(writeConfig.mode == .write)
        #expect(readWriteConfig.mode == .readWrite)
    }

    @Test("configuration cache modes")
    func configurationCacheModes() {
        var config = Kernel.File.Open.Configuration()

        config.cache = .buffered
        #expect(config.cache == .buffered)

        config.cache = .auto(policy: .fallbackToBuffered)
        #expect(config.cache == .auto(policy: .fallbackToBuffered))
    }
}

// MARK: - Integration Tests

#if !os(Windows)
    @Suite("Kernel.File Handle Integration")
    struct HandleIntegrationTests {

        @Test("open and close file with buffered mode")
        func openCloseBuffered() throws {
            let content = "Hello, World!"
            let pathString = makeTempFile(prefix: "handle-test", content: content)
            defer { removeTempFile(pathString) }

            try Kernel.Path.scope(pathString) { path in
                let config = Kernel.File.Open.Configuration(mode: .read)
                let handle = try Kernel.File.open(path, configuration: config)

                // Verify handle properties
                #expect(handle.direct == .buffered)

                // Close is consuming, just let it go out of scope
            }
        }

        // TODO: Enable when Handle.read is implemented in platform packages
        // @Test("read file with buffered mode")
        // func readBuffered() throws { ... }

        // TODO: Enable when Handle.write is implemented in platform packages
        // @Test("write file with buffered mode")
        // func writeBuffered() throws { ... }

        @Test("open with .auto(.fallbackToBuffered) succeeds")
        func openAutoFallback() throws {
            let content = "Auto fallback test"
            let pathString = makeTempFile(prefix: "handle-auto", content: content)
            defer { removeTempFile(pathString) }

            var config = Kernel.File.Open.Configuration(mode: .read)
            config.cache = .auto(policy: .fallbackToBuffered)

            try Kernel.Path.scope(pathString) { path in
                let handle = try Kernel.File.open(path, configuration: config)

                // On macOS: .uncached, on Linux: .buffered (because requirements unknown)
                #if os(macOS)
                    #expect(handle.direct == .uncached)
                #else
                    #expect(handle.direct == .buffered)
                #endif
            }
        }
    }
#endif

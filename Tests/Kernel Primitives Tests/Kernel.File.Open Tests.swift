// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import StandardsTestSupport
import Testing

@testable import Kernel_Primitives

extension Kernel.File.Open {
    #TestSuites
}

// MARK: - Mode Unit Tests

extension Kernel.File.Open.Test.Unit {
    @Test("Mode is OptionSet")
    func modeIsOptionSet() {
        let mode: Kernel.File.Open.Mode = [.read, .write]
        #expect(mode.contains(.read))
        #expect(mode.contains(.write))
    }

    @Test("Mode options are distinct")
    func modeOptionsDistinct() {
        let read = Kernel.File.Open.Mode.read
        let write = Kernel.File.Open.Mode.write

        #expect(read != write)
        #expect(!read.intersection(write).contains(.read))
    }

    @Test("Mode is Sendable")
    func modeIsSendable() {
        let mode: any Sendable = Kernel.File.Open.Mode.read
        #expect(mode is Kernel.File.Open.Mode)
    }

    @Test("Mode can combine read and write")
    func modeCombine() {
        let combined: Kernel.File.Open.Mode = [.read, .write]
        #expect(combined.contains(.read))
        #expect(combined.contains(.write))
    }
}

// MARK: - Options Unit Tests

extension Kernel.File.Open.Test.Unit {
    @Test("Options is OptionSet")
    func optionsIsOptionSet() {
        let options: Kernel.File.Open.Options = [.create, .truncate]
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
        #expect(!options.contains(.append))
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options: any Sendable = Kernel.File.Open.Options.create
        #expect(options is Kernel.File.Open.Options)
    }

    @Test("Options can be combined")
    func optionsCombine() {
        let combined = Kernel.File.Open.Options.create.union(.exclusive)
        #expect(combined.contains(.create))
        #expect(combined.contains(.exclusive))
    }

    @Test("all standard options are distinct")
    func standardOptionsDistinct() {
        let options: [Kernel.File.Open.Options] = [
            .create,
            .truncate,
            .append,
            .exclusive,
            .direct,
        ]

        for (i, a) in options.enumerated() {
            for (j, b) in options.enumerated() {
                if i != j {
                    #expect(!a.intersection(b).contains(a), "Options at index \(i) and \(j) should be distinct")
                }
            }
        }
    }
}

// MARK: - Edge Cases

extension Kernel.File.Open.Test.EdgeCase {
    @Test("empty options has zero raw value")
    func emptyOptions() {
        let empty = Kernel.File.Open.Options()
        #expect(empty.rawValue == 0)
    }

    @Test("exclusive without create is valid but semantically requires create")
    func exclusiveWithoutCreate() {
        // exclusive alone is valid at the API level
        let options = Kernel.File.Open.Options.exclusive
        #expect(options.contains(.exclusive))
        #expect(!options.contains(.create))
    }
}

// MARK: - Actual File Open Tests

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    import Kernel_Test_Support
    import SystemPackage

    extension Kernel.File.Open.Test.Unit {
        @Test("open existing file for read succeeds")
        func openExistingFileForRead() throws {
            let (path, fd) = try KernelIOTest.createTempFileWithContent("test", prefix: "open-test")
            defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

            let filePath = FilePath(path)
            let readFd = try Kernel.File.Open.open(
                path: filePath,
                mode: .read,
                options: [],
                permissions: Kernel.File.Permissions(rawValue: 0o644)
            )
            defer { close(readFd.rawValue) }

            #expect(readFd.isValid)
        }

        @Test("open with create creates new file")
        func openWithCreateCreatesFile() throws {
            let tmpdir = getenv("TMPDIR").map { String(cString: $0) } ?? "/tmp"
            let path = "\(tmpdir)/open-create-test-\(UInt32.random(in: 0...UInt32.max))"
            defer { unlink(path) }

            let filePath = FilePath(path)
            let fd = try Kernel.File.Open.open(
                path: filePath,
                mode: [.read, .write],
                options: .create,
                permissions: Kernel.File.Permissions(rawValue: 0o644)
            )
            defer { close(fd.rawValue) }

            #expect(fd.isValid)

            // Verify file exists
            var stat_buf = stat()
            let result = stat(path, &stat_buf)
            #expect(result == 0, "File should exist after create")
        }

        @Test("open with truncate truncates existing file")
        func openWithTruncateTruncatesFile() throws {
            let (path, fd) = try KernelIOTest.createTempFileWithContent("original content", prefix: "open-test")
            close(fd.rawValue)
            defer { unlink(path) }

            // Re-open with truncate
            let filePath = FilePath(path)
            let truncFd = try Kernel.File.Open.open(
                path: filePath,
                mode: [.read, .write],
                options: .truncate,
                permissions: Kernel.File.Permissions(rawValue: 0o644)
            )
            defer { close(truncFd.rawValue) }

            // Check file size is 0
            let size = lseek(truncFd.rawValue, 0, SEEK_END)
            #expect(size == 0, "File should be truncated to 0 bytes")
        }

        @Test("open with append positions at end")
        func openWithAppendPositionsAtEnd() throws {
            let (path, fd) = try KernelIOTest.createTempFileWithContent("initial", prefix: "open-test")
            close(fd.rawValue)
            defer { unlink(path) }

            // Re-open with append
            let filePath = FilePath(path)
            let appendFd = try Kernel.File.Open.open(
                path: filePath,
                mode: .write,
                options: .append,
                permissions: Kernel.File.Permissions(rawValue: 0o644)
            )
            defer { close(appendFd.rawValue) }

            // Write more data
            let extra = Array("_extra".utf8)
            _ = extra.withUnsafeBytes { ptr in
                write(appendFd.rawValue, ptr.baseAddress, ptr.count)
            }

            // Verify total content
            let readFd = open(path, O_RDONLY)
            defer { close(readFd) }
            var buffer = [UInt8](repeating: 0, count: 20)
            let bytesRead = buffer.withUnsafeMutableBytes { ptr in
                read(readFd, ptr.baseAddress, ptr.count)
            }
            let content = String(decoding: buffer.prefix(bytesRead), as: UTF8.self)
            #expect(content == "initial_extra")
        }

        @Test("open with exclusive fails if file exists")
        func openWithExclusiveFailsIfExists() throws {
            let (path, fd) = try KernelIOTest.createTempFile(prefix: "open-test")
            close(fd.rawValue)
            defer { unlink(path) }

            let filePath = FilePath(path)
            #expect(throws: Kernel.File.Open.Error.self) {
                _ = try Kernel.File.Open.open(
                    path: filePath,
                    mode: [.read, .write],
                    options: [.create, .exclusive],
                    permissions: Kernel.File.Permissions(rawValue: 0o644)
                )
            }
        }
    }

    extension Kernel.File.Open.Test.EdgeCase {
        @Test("open nonexistent file without create throws")
        func openNonexistentFileThrows() {
            let path = FilePath("/nonexistent/path/to/file")
            #expect(throws: Kernel.File.Open.Error.self) {
                _ = try Kernel.File.Open.open(
                    path: path,
                    mode: .read,
                    options: [],
                    permissions: Kernel.File.Permissions(rawValue: 0o644)
                )
            }
        }

        @Test("open directory for write throws")
        func openDirectoryForWriteThrows() {
            let path = FilePath("/tmp")
            #expect(throws: Kernel.File.Open.Error.self) {
                _ = try Kernel.File.Open.open(
                    path: path,
                    mode: .write,
                    options: [],
                    permissions: Kernel.File.Permissions(rawValue: 0o644)
                )
            }
        }
    }

#endif

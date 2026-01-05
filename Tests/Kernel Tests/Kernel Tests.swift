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
import SystemPackage
import Testing

@testable import Kernel

extension Kernel {
    #TestSuites
}


// MARK: - Integration Tests (require full Kernel module for file I/O)

extension Kernel.Test.Unit {
    @Test("Kernel namespace exists")
    func namespaceExists() {
        // Kernel is an enum namespace, verify it compiles
        _ = Kernel.self
    }

    @Test("open and close file")
    func openAndClose() throws {
        let path = Kernel.Temporary.filePath(prefix: "kernel-test")

        // Create and open
        let fd = try Kernel.File.Open.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        #expect(fd.isValid)

        // Close
        try Kernel.Close.close(fd)

        // Cleanup
        try? unlinkFile(at: path)
    }

    @Test("open nonexistent file throws path error")
    func openNonexistent() {
        #if os(Windows)
            let path = FilePath("C:\\nonexistent\\path\\that\\does\\not\\exist\\file.txt")
        #else
            let path = FilePath("/nonexistent/path/that/does/not/exist/file.txt")
        #endif

        #expect(throws: (any Error).self) {
            try Kernel.File.Open.open(
                path: path,
                mode: [.read],
                options: [],
                permissions: 0
            )
        }
    }

    @Test("write and read data")
    func writeAndRead() throws {
        let path = Kernel.Temporary.filePath(prefix: "kernel-test-rw")
        let testData: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"

        // Create file
        let fd = try Kernel.File.Open.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Close.close(fd)
            try? unlinkFile(at: path)
        }

        // Write
        let written = try testData.withUnsafeBytes { buffer in
            try Kernel.IO.Write.write(fd, from: buffer)
        }
        #expect(written == testData.count)

        // Read using pread (positional read from offset 0)
        var readBuffer = [UInt8](repeating: 0, count: testData.count)
        let bytesRead = try readBuffer.withUnsafeMutableBytes { buffer in
            try Kernel.IO.Read.pread(fd, into: buffer, at: 0)
        }

        #expect(bytesRead == testData.count)
        #expect(readBuffer == testData)
    }

    @Test("read returns 0 on EOF")
    func readEOF() throws {
        let path = Kernel.Temporary.filePath(prefix: "kernel-test-eof")

        // Create empty file
        let fd = try Kernel.File.Open.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Close.close(fd)
            try? unlinkFile(at: path)
        }

        // Read from empty file using pread at offset 0
        var buffer = [UInt8](repeating: 0, count: 100)
        let bytesRead = try buffer.withUnsafeMutableBytes { buf in
            try Kernel.IO.Read.pread(fd, into: buf, at: 0)
        }

        #expect(bytesRead == 0)  // EOF returns 0, not error
    }
}

// MARK: - Edge Cases (Integration)

extension Kernel.Test.EdgeCase {
    @Test("close invalid descriptor throws")
    func closeInvalid() {
        #expect(throws: (any Error).self) {
            try Kernel.Close.close(.invalid)
        }
    }

    @Test("read from invalid descriptor throws")
    func readInvalid() {
        var buffer = [UInt8](repeating: 0, count: 10)
        #expect(throws: (any Error).self) {
            try buffer.withUnsafeMutableBytes { buf in
                try Kernel.IO.Read.read(.invalid, into: buf)
            }
        }
    }

    @Test("write to invalid descriptor throws")
    func writeInvalid() {
        let data: [UInt8] = [1, 2, 3]
        #expect(throws: (any Error).self) {
            try data.withUnsafeBytes { buf in
                try Kernel.IO.Write.write(.invalid, from: buf)
            }
        }
    }
}

// MARK: - Helper for cleanup

/// Helper to unlink (delete) a file - used in test cleanup
private func unlinkFile(at path: FilePath) throws {
    try Kernel.Unlink.unlink(path)
}

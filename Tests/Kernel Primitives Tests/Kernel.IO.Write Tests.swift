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

import Kernel_Test_Support
import StandardsTestSupport
import Testing

@testable import Kernel_Primitives

extension Kernel.IO.Write {
    #TestSuites
}

// MARK: - Write Tests

#if !os(Windows)

extension Kernel.IO.Write.Test.Unit {
    @Test("write writes bytes to file")
    func writeWritesBytesToFile() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        let content = Array("Hello, World!".utf8)
        let bytesWritten = try content.withUnsafeBytes { ptr in
            try Kernel.IO.Write.write(fd, from: ptr)
        }

        #expect(bytesWritten == 13)

        // Verify by reading back
        lseek(fd.rawValue, 0, SEEK_SET)
        var buffer = [UInt8](repeating: 0, count: 13)
        _ = buffer.withUnsafeMutableBytes { ptr in
            read(fd.rawValue, ptr.baseAddress, ptr.count)
        }
        #expect(String(decoding: buffer, as: UTF8.self) == "Hello, World!")
    }

    @Test("write with empty buffer returns 0")
    func writeWithEmptyBufferReturnsZero() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        let emptyBuffer = UnsafeRawBufferPointer(start: nil, count: 0)
        let bytesWritten = try Kernel.IO.Write.write(fd, from: emptyBuffer)

        #expect(bytesWritten == 0)
    }

    @Test("write advances file position")
    func writeAdvancesFilePosition() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        let initialPos = lseek(fd.rawValue, 0, SEEK_CUR)

        let content = Array("12345".utf8)
        _ = try content.withUnsafeBytes { ptr in
            try Kernel.IO.Write.write(fd, from: ptr)
        }

        let finalPos = lseek(fd.rawValue, 0, SEEK_CUR)
        #expect(finalPos == initialPos + 5)
    }

    @Test("multiple writes append correctly")
    func multipleWritesAppend() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        let first = Array("First".utf8)
        let second = Array("Second".utf8)

        _ = try first.withUnsafeBytes { try Kernel.IO.Write.write(fd, from: $0) }
        _ = try second.withUnsafeBytes { try Kernel.IO.Write.write(fd, from: $0) }

        // Verify combined content
        lseek(fd.rawValue, 0, SEEK_SET)
        var buffer = [UInt8](repeating: 0, count: 11)
        _ = buffer.withUnsafeMutableBytes { ptr in
            read(fd.rawValue, ptr.baseAddress, ptr.count)
        }
        #expect(String(decoding: buffer, as: UTF8.self) == "FirstSecond")
    }

    @Test("pwrite writes at offset without changing position")
    func pwriteWritesAtOffset() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        // Write initial content
        let initial = Array("XXXXXXXXXX".utf8)
        _ = try initial.withUnsafeBytes { try Kernel.IO.Write.write(fd, from: $0) }

        // Record position after write
        let posAfterWrite = lseek(fd.rawValue, 0, SEEK_CUR)

        // pwrite "ABC" at offset 3
        let patch = Array("ABC".utf8)
        let bytesWritten = try patch.withUnsafeBytes { ptr in
            try Kernel.IO.Write.pwrite(fd, from: ptr, at: Kernel.File.Offset(3))
        }

        #expect(bytesWritten == 3)

        // Position should be unchanged
        let posAfterPwrite = lseek(fd.rawValue, 0, SEEK_CUR)
        #expect(posAfterPwrite == posAfterWrite)

        // Verify content
        lseek(fd.rawValue, 0, SEEK_SET)
        var buffer = [UInt8](repeating: 0, count: 10)
        _ = buffer.withUnsafeMutableBytes { ptr in
            read(fd.rawValue, ptr.baseAddress, ptr.count)
        }
        #expect(String(decoding: buffer, as: UTF8.self) == "XXXABCXXXX")
    }

    @Test("pwrite with empty buffer returns 0")
    func pwriteWithEmptyBufferReturnsZero() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        let emptyBuffer = UnsafeRawBufferPointer(start: nil, count: 0)
        let bytesWritten = try Kernel.IO.Write.pwrite(fd, from: emptyBuffer, at: Kernel.File.Offset(0))

        #expect(bytesWritten == 0)
    }

    @Test("pwrite can extend file")
    func pwriteCanExtendFile() throws {
        let (path, fd) = try KernelIOTest.createTempFile(prefix: "write-test")
        defer { KernelIOTest.cleanupTempFile(path: path, fd: fd) }

        // Write at offset 10 in empty file
        let content = Array("End".utf8)
        let bytesWritten = try content.withUnsafeBytes { ptr in
            try Kernel.IO.Write.pwrite(fd, from: ptr, at: Kernel.File.Offset(10))
        }

        #expect(bytesWritten == 3)

        // File should be 13 bytes (10 zeros + "End")
        let size = lseek(fd.rawValue, 0, SEEK_END)
        #expect(size == 13)
    }
}

// MARK: - Error Tests

extension Kernel.IO.Write.Test.EdgeCase {
    @Test("write throws on invalid descriptor")
    func writeThrowsOnInvalidDescriptor() {
        let invalidFd = Kernel.Descriptor(rawValue: -1)
        let content = Array("test".utf8)

        #expect(throws: Kernel.IO.Write.Error.self) {
            try content.withUnsafeBytes { ptr in
                try Kernel.IO.Write.write(invalidFd, from: ptr)
            }
        }
    }

    @Test("pwrite throws on invalid descriptor")
    func pwriteThrowsOnInvalidDescriptor() {
        let invalidFd = Kernel.Descriptor(rawValue: -1)
        let content = Array("test".utf8)

        #expect(throws: Kernel.IO.Write.Error.self) {
            try content.withUnsafeBytes { ptr in
                try Kernel.IO.Write.pwrite(invalidFd, from: ptr, at: Kernel.File.Offset(0))
            }
        }
    }
}

#endif

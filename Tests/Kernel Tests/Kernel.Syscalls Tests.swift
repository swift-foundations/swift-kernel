//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import StandardsTestSupport
import SystemPackage
import Testing

@testable import Kernel

extension Kernel.Syscalls {
    #TestSuites
}

// MARK: - Open/Close Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("open and close file")
    func openAndClose() throws {
        let path = FilePath("/tmp/kernel-test-\(ProcessInfo.processInfo.processIdentifier).txt")

        // Create and open
        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        #expect(Kernel.isValid(fd))

        // Close
        try Kernel.Syscalls.close(fd)

        // Cleanup
        try? Kernel.Syscalls.unlink(path: path)
    }

    @Test("open nonexistent file throws path.notFound")
    func openNonexistent() {
        let path = FilePath("/nonexistent/path/that/does/not/exist/file.txt")

        #expect(throws: Kernel.Error.path(.notFound)) {
            try Kernel.Syscalls.open(
                path: path,
                mode: [.read],
                options: [],
                permissions: 0
            )
        }
    }
}

// MARK: - Read/Write Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("write and read data")
    func writeAndRead() throws {
        let path = FilePath("/tmp/kernel-test-rw-\(ProcessInfo.processInfo.processIdentifier).txt")
        let testData: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"

        // Create file
        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Write
        let written = try testData.withUnsafeBytes { buffer in
            try Kernel.Syscalls.write(fd, from: buffer)
        }
        #expect(written == testData.count)

        // Seek to beginning
        let position = try Kernel.Syscalls.seek(fd, offset: 0, origin: .start)
        #expect(position == 0)

        // Read
        var readBuffer = [UInt8](repeating: 0, count: testData.count)
        let bytesRead = try readBuffer.withUnsafeMutableBytes { buffer in
            try Kernel.Syscalls.read(fd, into: buffer)
        }

        #expect(bytesRead == testData.count)
        #expect(readBuffer == testData)
    }

    @Test("read returns 0 on EOF")
    func readEOF() throws {
        let path = FilePath("/tmp/kernel-test-eof-\(ProcessInfo.processInfo.processIdentifier).txt")

        // Create empty file
        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Read from empty file
        var buffer = [UInt8](repeating: 0, count: 100)
        let bytesRead = try buffer.withUnsafeMutableBytes { buf in
            try Kernel.Syscalls.read(fd, into: buf)
        }

        #expect(bytesRead == 0) // EOF returns 0, not error
    }
}

// MARK: - Stat Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("stat returns file metadata")
    func statFile() throws {
        let path = FilePath("/tmp/kernel-test-stat-\(ProcessInfo.processInfo.processIdentifier).txt")
        let testData: [UInt8] = [1, 2, 3, 4, 5]

        // Create file with known content
        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: .write,
            options: [.create, .truncate],
            permissions: 0o644
        )

        _ = try testData.withUnsafeBytes { buffer in
            try Kernel.Syscalls.write(fd, from: buffer)
        }
        try Kernel.Syscalls.close(fd)

        defer {
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Stat
        let stat = try Kernel.Syscalls.stat(path: path, followSymlinks: true)

        #expect(stat.size == Int64(testData.count))
        #expect(stat.type == .regular)
    }

    @Test("stat on directory returns directory type")
    func statDirectory() throws {
        let path = FilePath("/tmp")
        let stat = try Kernel.Syscalls.stat(path: path, followSymlinks: true)

        #expect(stat.type == .directory)
    }

    @Test("fstat matches stat")
    func fstatMatchesStat() throws {
        let path = FilePath("/tmp/kernel-test-fstat-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: .write,
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        let fstat = try Kernel.Syscalls.fstat(fd)
        let stat = try Kernel.Syscalls.stat(path: path, followSymlinks: true)

        #expect(fstat.inode == stat.inode)
        #expect(fstat.device == stat.device)
        #expect(fstat.type == stat.type)
    }
}

// MARK: - Seek Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("seek from start")
    func seekStart() throws {
        let path = FilePath("/tmp/kernel-test-seek-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Write some data
        let data: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        _ = try data.withUnsafeBytes { try Kernel.Syscalls.write(fd, from: $0) }

        // Seek from start
        let pos = try Kernel.Syscalls.seek(fd, offset: 5, origin: .start)
        #expect(pos == 5)
    }

    @Test("seek from end")
    func seekEnd() throws {
        let path = FilePath("/tmp/kernel-test-seek-end-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Write 10 bytes
        let data: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        _ = try data.withUnsafeBytes { try Kernel.Syscalls.write(fd, from: $0) }

        // Seek to 2 bytes before end
        let pos = try Kernel.Syscalls.seek(fd, offset: -2, origin: .end)
        #expect(pos == 8)
    }
}

// MARK: - Duplicate Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("duplicate creates independent descriptor")
    func duplicate() throws {
        let path = FilePath("/tmp/kernel-test-dup-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        let fd2 = try Kernel.Syscalls.duplicate(fd)
        #expect(Kernel.isValid(fd2))
        #expect(fd != fd2)

        // Close duplicate
        try Kernel.Syscalls.close(fd2)

        // Original should still work
        let pos = try Kernel.Syscalls.seek(fd, offset: 0, origin: .current)
        #expect(pos >= 0)
    }
}

// MARK: - Edge Cases

extension Kernel.Syscalls.Test.EdgeCase {
    @Test("close invalid descriptor throws")
    func closeInvalid() {
        #expect(throws: Kernel.Error.descriptor(.invalid)) {
            try Kernel.Syscalls.close(-1)
        }
    }

    @Test("read from invalid descriptor throws")
    func readInvalid() {
        var buffer = [UInt8](repeating: 0, count: 10)
        #expect(throws: Kernel.Error.descriptor(.invalid)) {
            try buffer.withUnsafeMutableBytes { buf in
                try Kernel.Syscalls.read(-1, into: buf)
            }
        }
    }

    @Test("write to invalid descriptor throws")
    func writeInvalid() {
        let data: [UInt8] = [1, 2, 3]
        #expect(throws: Kernel.Error.descriptor(.invalid)) {
            try data.withUnsafeBytes { buf in
                try Kernel.Syscalls.write(-1, from: buf)
            }
        }
    }
}

// MARK: - Lock/Unlock Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("lock and unlock whole file")
    func lockUnlockWholeFile() throws {
        let path = FilePath("/tmp/kernel-test-lock-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Acquire exclusive lock
        let acquired = try Kernel.Syscalls.lock(fd, range: .file, exclusive: true, wait: true)
        #expect(acquired == true)

        // Unlock
        try Kernel.Syscalls.unlock(fd, range: .file)
    }

    @Test("lock byte range")
    func lockByteRange() throws {
        let path = FilePath("/tmp/kernel-test-lock-range-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Write some data
        let data: [UInt8] = Array(repeating: 0, count: 100)
        _ = try data.withUnsafeBytes { try Kernel.Syscalls.write(fd, from: $0) }

        // Lock bytes 10-50
        let acquired = try Kernel.Syscalls.lock(
            fd,
            range: .bytes(start: 10, length: 40),
            exclusive: true,
            wait: true
        )
        #expect(acquired == true)

        // Unlock
        try Kernel.Syscalls.unlock(fd, range: .bytes(start: 10, length: 40))
    }

    @Test("shared lock allows multiple readers")
    func sharedLock() throws {
        let path = FilePath("/tmp/kernel-test-shared-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd1 = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        let fd2 = try Kernel.Syscalls.open(
            path: path,
            mode: [.read],
            options: [],
            permissions: 0
        )

        defer {
            try? Kernel.Syscalls.close(fd1)
            try? Kernel.Syscalls.close(fd2)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // First shared lock
        let acquired1 = try Kernel.Syscalls.lock(fd1, range: .file, exclusive: false, wait: true)
        #expect(acquired1 == true)

        // Second shared lock should also succeed
        let acquired2 = try Kernel.Syscalls.lock(fd2, range: .file, exclusive: false, wait: true)
        #expect(acquired2 == true)

        // Unlock both
        try Kernel.Syscalls.unlock(fd1, range: .file)
        try Kernel.Syscalls.unlock(fd2, range: .file)
    }

    @Test("lock on different byte ranges")
    func lockDifferentRanges() throws {
        // Note: POSIX fcntl locks are per-process, not per-fd.
        // Two fds in the same process to the same file share locks.
        // Testing cross-process contention requires spawning processes.
        // This test verifies non-overlapping ranges work correctly.
        let path = FilePath("/tmp/kernel-test-ranges-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        // Write some data
        let data: [UInt8] = Array(repeating: 0, count: 200)
        _ = try data.withUnsafeBytes { try Kernel.Syscalls.write(fd, from: $0) }

        // Lock first range
        let acquired1 = try Kernel.Syscalls.lock(
            fd,
            range: .bytes(start: 0, length: 50),
            exclusive: true,
            wait: true
        )
        #expect(acquired1 == true)

        // Lock second non-overlapping range
        let acquired2 = try Kernel.Syscalls.lock(
            fd,
            range: .bytes(start: 100, length: 50),
            exclusive: true,
            wait: true
        )
        #expect(acquired2 == true)

        // Unlock both
        try Kernel.Syscalls.unlock(fd, range: .bytes(start: 0, length: 50))
        try Kernel.Syscalls.unlock(fd, range: .bytes(start: 100, length: 50))
    }
}

// MARK: - Statfs Unit Tests

extension Kernel.Syscalls.Test.Unit {
    @Test("statfs returns filesystem info")
    func statfsPath() throws {
        let path = FilePath("/tmp")

        let fs = try Kernel.Syscalls.statfs(path: path)

        // Basic sanity checks
        #expect(fs.blockSize > 0)
        #expect(fs.blocks > 0)
    }

    @Test("fstatfs returns filesystem info")
    func fstatfsDescriptor() throws {
        let path = FilePath("/tmp/kernel-test-fstatfs-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        let fs = try Kernel.Syscalls.fstatfs(fd)

        #expect(fs.blockSize > 0)
        #expect(fs.blocks > 0)
    }

    @Test("statfs and fstatfs match for same filesystem")
    func statfsMatchesFstatfs() throws {
        let path = FilePath("/tmp/kernel-test-statfs-match-\(ProcessInfo.processInfo.processIdentifier).txt")

        let fd = try Kernel.Syscalls.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: 0o644
        )

        defer {
            try? Kernel.Syscalls.close(fd)
            try? Kernel.Syscalls.unlink(path: path)
        }

        let statfs = try Kernel.Syscalls.statfs(path: FilePath("/tmp"))
        let fstatfs = try Kernel.Syscalls.fstatfs(fd)

        // Same filesystem should have same type and block size
        #expect(statfs.type == fstatfs.type)
        #expect(statfs.blockSize == fstatfs.blockSize)
    }
}

// MARK: - Helper for cleanup

import Foundation

extension Kernel.Syscalls {
    /// Helper to unlink (delete) a file - used in test cleanup
    fileprivate static func unlink(path: FilePath) throws {
        try path.withPlatformString { cString in
            #if canImport(Darwin)
            if Darwin.unlink(cString) != 0 {
                throw Kernel.Error.currentPosixError()
            }
            #elseif canImport(Glibc)
            if Glibc.unlink(cString) != 0 {
                throw Kernel.Error.currentPosixError()
            }
            #elseif canImport(Musl)
            if Musl.unlink(cString) != 0 {
                throw Kernel.Error.currentPosixError()
            }
            #endif
        }
    }
}

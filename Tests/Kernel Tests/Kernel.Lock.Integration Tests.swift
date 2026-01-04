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

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    import ucrt
    import WinSDK
#endif

#if canImport(Foundation)
    import Foundation
#endif

// Integration suite for multi-process lock tests
// Note: Kernel.Lock.Test is defined in Kernel Primitives Tests via #TestSuites
// This integration test target defines its own suite
@Suite("Kernel.Lock Integration")
struct KernelLockIntegration {}

// MARK: - Cross-Platform Test Helpers

/// Creates a temporary file using Kernel APIs and returns its path and descriptor.
private func createTempFile(prefix: String) throws -> (path: FilePath, fd: Kernel.Descriptor) {
    let path = Kernel.Temporary.filePath(prefix: prefix)
    let fd = try Kernel.File.Open.open(
        path: path,
        mode: [.read, .write],
        options: [.create, .truncate],
        permissions: 0o644
    )
    // Write some data so the file isn't empty (needed for byte-range locking)
    let data = [UInt8](repeating: 0x78, count: 1024)  // 'x' repeated
    _ = try data.withUnsafeBytes { buffer in
        try Kernel.IO.Write.write(fd, from: buffer)
    }
    return (path, fd)
}

/// Cleans up a temporary file.
private func cleanupTempFile(path: FilePath, fd: Kernel.Descriptor) {
    try? Kernel.Close.close(fd)
    #if os(Windows)
        try? path.withPlatformString { wPath in
            _ = DeleteFileW(wPath)
        }
    #else
        path.withPlatformString { cPath in
            _ = unlink(cPath)
        }
    #endif
}

// MARK: - Token Integration Tests

extension KernelLockIntegration {
    @Test("Token acquires and releases lock")
    func tokenAcquiresAndReleasesLock() throws {
        let (path, fd) = try createTempFile(prefix: "kernel-lock-token")
        defer { cleanupTempFile(path: path, fd: fd) }

        #expect(fd.isValid, "Failed to create test file")

        // Acquire exclusive lock
        var token = try Kernel.Lock.Token(
            descriptor: fd,
            range: .file,
            kind: .exclusive,
            acquire: .wait
        )

        // Release the lock
        try token.release()
    }

    @Test("Try lock returns immediately when uncontested")
    func tryLockUncontested() throws {
        let (path, fd) = try createTempFile(prefix: "kernel-lock-try")
        defer { cleanupTempFile(path: path, fd: fd) }

        #expect(fd.isValid, "Failed to create test file")

        // Try to acquire lock without blocking - should succeed
        var token = try Kernel.Lock.Token(
            descriptor: fd,
            range: .file,
            kind: .exclusive,
            acquire: .try
        )

        try token.release()
    }
}

// MARK: - Multi-Process Contention Tests
// Note: These tests require Foundation.Process and use POSIX-specific helpers.
// They spawn a separate process to test lock contention across processes.

#if canImport(Foundation) && !os(Windows)

    /// POSIX-only helper that returns String path for use with Foundation.Process
    private func createTempFileForProcess(prefix: String) -> (path: String, fd: Int32) {
        let path = Kernel.Temporary.filePath(prefix: prefix).string
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        // Write some data so the file isn't empty
        _ = "x".withCString { ptr in
            write(fd, ptr, 1024)
        }
        return (path, fd)
    }

    extension KernelLockIntegration {

        /// Path to the lock test helper executable
        private static var helperPath: String {
            // Check Xcode build location first (via environment variable)
            if let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
                return "\(builtProductsDir)/_Lock Test Process"
            }
            // Fall back to SPM build directory (use absolute path from package root)
            #if os(macOS)
                let buildDir = ".build/arm64-apple-macosx/debug"
            #elseif os(Linux)
                let buildDir = ".build/debug"
            #else
                let buildDir = ".build/debug"
            #endif
            // Get the package root by finding the directory containing Package.swift
            // relative to the test file location
            let packageRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // Kernel Tests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // swift-kernel
            return packageRoot.appendingPathComponent(buildDir).appendingPathComponent("_Lock Test Process").path
        }

        @Test("Exclusive lock blocks try-exclusive from another process")
        func exclusiveBlocksTryExclusive() throws {
            let (path, fd) = createTempFileForProcess(prefix: "kernel-contention")
            defer {
                close(fd)
                unlink(path)
            }

            #expect(fd >= 0, "Failed to create test file")

            // Acquire exclusive lock in this process
            var token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: .file,
                kind: .exclusive,
                acquire: .wait
            )

            // Spawn helper to try acquiring exclusive lock (should fail)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path, "--signal-ready"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }

        @Test("Exclusive lock blocks try-shared from another process")
        func exclusiveBlocksTryShared() throws {
            let (path, fd) = createTempFileForProcess(prefix: "kernel-contention")
            defer {
                close(fd)
                unlink(path)
            }

            #expect(fd >= 0, "Failed to create test file")

            // Acquire exclusive lock in this process
            var token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: .file,
                kind: .exclusive,
                acquire: .wait
            )

            // Spawn helper to try acquiring shared lock (should fail)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-shared", path]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }

        @Test("Shared lock allows try-shared from another process")
        func sharedAllowsTryShared() throws {
            let (path, fd) = createTempFileForProcess(prefix: "kernel-contention")
            defer {
                close(fd)
                unlink(path)
            }

            #expect(fd >= 0, "Failed to create test file")

            // Acquire shared lock in this process
            var token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: .file,
                kind: .shared,
                acquire: .wait
            )

            // Spawn helper to try acquiring shared lock (should succeed)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-shared", path, "--hold", "0", "--signal-ready"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 0, "Helper should exit with 0 (success)")
            #expect(output.contains("READY"), "Helper should report READY")
            #expect(output.contains("RELEASED"), "Helper should report RELEASED")

            try token.release()
        }

        @Test("Shared lock blocks try-exclusive from another process")
        func sharedBlocksTryExclusive() throws {
            let (path, fd) = createTempFileForProcess(prefix: "kernel-contention")
            defer {
                close(fd)
                unlink(path)
            }

            #expect(fd >= 0, "Failed to create test file")

            // Acquire shared lock in this process
            var token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: .file,
                kind: .shared,
                acquire: .wait
            )

            // Spawn helper to try acquiring exclusive lock (should fail)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }

        @Test("Non-overlapping byte ranges don't conflict")
        func nonOverlappingRangesDontConflict() throws {
            let (path, fd) = createTempFileForProcess(prefix: "kernel-contention")
            defer {
                close(fd)
                unlink(path)
            }

            #expect(fd >= 0, "Failed to create test file")

            // Acquire exclusive lock on bytes 0-100 in this process
            var token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: .bytes(start: Kernel.File.Offset(0), end: Kernel.File.Offset(100)),
                kind: .exclusive,
                acquire: .wait
            )

            // Spawn helper to try acquiring exclusive lock on bytes 200-300 (should succeed)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path, "--range", "200-300", "--hold", "0", "--signal-ready"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 0, "Helper should exit with 0 (success)")
            #expect(output.contains("READY"), "Helper should report READY")

            try token.release()
        }

        @Test("Overlapping byte ranges do conflict")
        func overlappingRangesConflict() throws {
            let (path, fd) = createTempFileForProcess(prefix: "kernel-contention")
            defer {
                close(fd)
                unlink(path)
            }

            #expect(fd >= 0, "Failed to create test file")

            // Acquire exclusive lock on bytes 0-200 in this process
            var token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: .bytes(start: Kernel.File.Offset(0), end: Kernel.File.Offset(200)),
                kind: .exclusive,
                acquire: .wait
            )

            // Spawn helper to try acquiring exclusive lock on bytes 100-300 (overlaps, should fail)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path, "--range", "100-300"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }
    }
#endif

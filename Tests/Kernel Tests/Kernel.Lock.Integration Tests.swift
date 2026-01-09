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

import Kernel_Primitives
import Kernel_Test_Support
import Test_Support_Primitives
import Testing

@testable import Kernel

#if canImport(Foundation)
    import Foundation
#endif

// Integration suite for multi-process lock tests
// Note: Kernel.Lock.Test is defined in Kernel Primitives Tests via #TestSuites
// This integration test target defines its own suite
@Suite("Kernel.Lock Integration")
struct KernelLockIntegration {}

// MARK: - Cross-Platform Test Helpers

/// Creates a temporary file and executes body with the path and descriptor.
/// File is automatically cleaned up after body completes.
private func withTempFile<R>(
    prefix: String,
    _ body: (borrowing Kernel.Path, Kernel.Descriptor) throws -> R
) throws -> R {
    let pathString = Kernel.Temporary.filePath(prefix: prefix)
    return try Kernel.Path.scope(pathString) { path in
        let fd = try Kernel.File.Open.open(
            path: path,
            mode: [.read, .write],
            options: [.create, .truncate],
            permissions: .ownerReadWrite
        )
        // Write some data so the file isn't empty (needed for byte-range locking)
        let data = [UInt8](repeating: 0x78, count: 1024)  // 'x' repeated
        _ = try data.withUnsafeBytes { buffer in
            try Kernel.IO.Write.write(fd, from: buffer)
        }
        defer {
            try? Kernel.Close.close(fd)
            try? Kernel.Unlink.unlink(path)
        }
        return try body(path, fd)
    }
}

// MARK: - Token Integration Tests

extension KernelLockIntegration {
    @Test("Token acquires and releases lock")
    func tokenAcquiresAndReleasesLock() throws {
        try withTempFile(prefix: "kernel-lock-token") { _, fd in
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
    }

    @Test("Try lock returns immediately when uncontested")
    func tryLockUncontested() throws {
        try withTempFile(prefix: "kernel-lock-try") { _, fd in
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
}

// MARK: - Multi-Process Contention Tests
// Note: These tests require Foundation.Process and use POSIX-specific helpers.
// They spawn a separate process to test lock contention across processes.

#if canImport(Foundation) && !os(Windows)

    /// POSIX-only helper for cross-process lock testing.
    /// Provides both the path String (for subprocess args) and descriptor.
    /// File is cleaned up after body completes.
    private func withTempFileForProcess<R>(
        prefix: String,
        _ body: (_ pathString: String, _ fd: Kernel.Descriptor) throws -> R
    ) throws -> R {
        let pathString = Kernel.Temporary.filePath(prefix: prefix)
        return try Kernel.Path.scope(pathString) { path in
            let fd = try Kernel.File.Open.open(
                path: path,
                mode: [.read, .write],
                options: [.create, .truncate],
                permissions: .ownerReadWrite
            )
            // Write some data so the file isn't empty (needed for byte-range locking)
            let data = [UInt8](repeating: 0x78, count: 1024)
            _ = try? data.withUnsafeBytes { buffer in
                try Kernel.IO.Write.write(fd, from: buffer)
            }
            defer {
                try? Kernel.Close.close(fd)
                try? Kernel.Unlink.unlink(path)
            }
            return try body(pathString, fd)
        }
    }

    extension KernelLockIntegration {

        /// Path to the lock test helper executable
        private static var helperPath: String {
            // Check Xcode build location first (via environment variable)
            if let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
                return "\(builtProductsDir)/_Lock Test Process"
            }
            // Fall back to SPM build directory (use absolute path from package root)
            #if DEBUG
                let config = "debug"
            #else
                let config = "release"
            #endif
            #if os(macOS)
                let buildDir = ".build/arm64-apple-macosx/\(config)"
            #elseif os(Linux)
                let buildDir = ".build/\(config)"
            #else
                let buildDir = ".build/\(config)"
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
            try withTempFileForProcess(prefix: "kernel-contention") { pathString, fd in
                #expect(fd.isValid, "Failed to create test file")

                // Acquire exclusive lock in this process
                var token = try Kernel.Lock.Token(
                    descriptor: fd,
                    range: .file,
                    kind: .exclusive,
                    acquire: .wait
                )

                // Spawn helper to try acquiring exclusive lock (should fail)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.helperPath)
                process.arguments = ["try-exclusive", pathString, "--signal-ready"]

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

        @Test("Exclusive lock blocks try-shared from another process")
        func exclusiveBlocksTryShared() throws {
            try withTempFileForProcess(prefix: "kernel-contention") { pathString, fd in
                #expect(fd.isValid, "Failed to create test file")

                // Acquire exclusive lock in this process
                var token = try Kernel.Lock.Token(
                    descriptor: fd,
                    range: .file,
                    kind: .exclusive,
                    acquire: .wait
                )

                // Spawn helper to try acquiring shared lock (should fail)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.helperPath)
                process.arguments = ["try-shared", pathString]

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

        @Test("Shared lock allows try-shared from another process")
        func sharedAllowsTryShared() throws {
            try withTempFileForProcess(prefix: "kernel-contention") { pathString, fd in
                #expect(fd.isValid, "Failed to create test file")

                // Acquire shared lock in this process
                var token = try Kernel.Lock.Token(
                    descriptor: fd,
                    range: .file,
                    kind: .shared,
                    acquire: .wait
                )

                // Spawn helper to try acquiring shared lock (should succeed)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.helperPath)
                process.arguments = ["try-shared", pathString, "--hold", "0", "--signal-ready"]

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
        }

        @Test("Shared lock blocks try-exclusive from another process")
        func sharedBlocksTryExclusive() throws {
            try withTempFileForProcess(prefix: "kernel-contention") { pathString, fd in
                #expect(fd.isValid, "Failed to create test file")

                // Acquire shared lock in this process
                var token = try Kernel.Lock.Token(
                    descriptor: fd,
                    range: .file,
                    kind: .shared,
                    acquire: .wait
                )

                // Spawn helper to try acquiring exclusive lock (should fail)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.helperPath)
                process.arguments = ["try-exclusive", pathString]

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

        @Test("Non-overlapping byte ranges don't conflict")
        func nonOverlappingRangesDontConflict() throws {
            try withTempFileForProcess(prefix: "kernel-contention") { pathString, fd in
                #expect(fd.isValid, "Failed to create test file")

                // Acquire exclusive lock on bytes 0-100 in this process
                var token = try Kernel.Lock.Token(
                    descriptor: fd,
                    range: .bytes(start: Kernel.File.Offset(0), end: Kernel.File.Offset(100)),
                    kind: .exclusive,
                    acquire: .wait
                )

                // Spawn helper to try acquiring exclusive lock on bytes 200-300 (should succeed)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.helperPath)
                process.arguments = ["try-exclusive", pathString, "--range", "200-300", "--hold", "0", "--signal-ready"]

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
        }

        @Test("Overlapping byte ranges do conflict")
        func overlappingRangesConflict() throws {
            try withTempFileForProcess(prefix: "kernel-contention") { pathString, fd in
                #expect(fd.isValid, "Failed to create test file")

                // Acquire exclusive lock on bytes 0-200 in this process
                var token = try Kernel.Lock.Token(
                    descriptor: fd,
                    range: .bytes(start: Kernel.File.Offset(0), end: Kernel.File.Offset(200)),
                    kind: .exclusive,
                    acquire: .wait
                )

                // Spawn helper to try acquiring exclusive lock on bytes 100-300 (overlaps, should fail)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.helperPath)
                process.arguments = ["try-exclusive", pathString, "--range", "100-300"]

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
    }
#endif

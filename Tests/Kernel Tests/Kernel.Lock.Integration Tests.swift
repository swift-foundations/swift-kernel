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

import Kernel_Test_Support
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Kernel

#if canImport(Foundation)
    import Foundation
#endif

// Integration suite for multi-process lock tests
// Note: Kernel.Lock.Test is defined in Kernel Primitives Tests via #Tests
// This integration test target defines its own suite
@Suite("Kernel.Lock Integration")
struct KernelLockIntegration {}

// MARK: - Helpers

/// Creates a temporary file with 1KB of test data. Returns the path string.
/// Caller is responsible for cleanup via `cleanupLockFile`.
private func createLockFile(prefix: Swift.String) throws -> Swift.String {
    let pathString = Kernel.Temporary.filePath(prefix: prefix)
    try Path.scope(pathString) { path in
        let fd = try Kernel.File.Open.open(
            path: path,
            mode: .readWrite,
            options: [.create, .truncate],
            permissions: .ownerReadWrite
        )
        let data = [UInt8](repeating: 0x78, count: 1024)
        _ = try data.withUnsafeBytes { buffer in
            try Kernel.IO.Write.write(fd, from: buffer)
        }
        // fd drops → file closed but persists on disk
    }
    return pathString
}

/// Opens a file for locking. Returns a consuming descriptor for Lock.Token.
private func openForLock(_ pathString: Swift.String) throws -> Kernel.Descriptor {
    try Path.scope(pathString) { path in
        try Kernel.File.Open.open(path: path, mode: .readWrite, options: [], permissions: .ownerReadWrite)
    }
}

/// Deletes the file at the given path.
private func cleanupLockFile(_ pathString: Swift.String) {
    try? Path.scope(pathString) { path in
        try Kernel.File.Delete.delete(path)
    }
}

// MARK: - Token Integration Tests

extension KernelLockIntegration {
    @Test
    func `token acquires and releases lock`() throws {
        let path = try createLockFile(prefix: "kernel-lock-token")
        defer { cleanupLockFile(path) }

        let fd = try openForLock(path)
        var token = try Kernel.Lock.Token(
            descriptor: fd,
            range: .file,
            kind: .exclusive,
            acquire: .wait
        )
        try token.release()
    }

    @Test
    func `try lock returns immediately when uncontested`() throws {
        let path = try createLockFile(prefix: "kernel-lock-try")
        defer { cleanupLockFile(path) }

        let fd = try openForLock(path)
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

    extension KernelLockIntegration {

        /// Path to the lock test helper executable
        private static var helperPath: Swift.String {
            if let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
                return "\(builtProductsDir)/_Lock Test Process"
            }
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
            let packageRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // Kernel Tests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // swift-kernel
            return packageRoot.appendingPathComponent(buildDir).appendingPathComponent("_Lock Test Process").path
        }

        @Test
        func `exclusive lock blocks try-exclusive from another process`() throws {
            let path = try createLockFile(prefix: "kernel-contention")
            defer { cleanupLockFile(path) }

            let fd = try openForLock(path)
            var token = try Kernel.Lock.Token(
                descriptor: fd,
                range: .file,
                kind: .exclusive,
                acquire: .wait
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path, "--signal-ready"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = Swift.String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }

        @Test
        func `exclusive lock blocks try-shared from another process`() throws {
            let path = try createLockFile(prefix: "kernel-contention")
            defer { cleanupLockFile(path) }

            let fd = try openForLock(path)
            var token = try Kernel.Lock.Token(
                descriptor: fd,
                range: .file,
                kind: .exclusive,
                acquire: .wait
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-shared", path]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = Swift.String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }

        @Test
        func `shared lock allows try-shared from another process`() throws {
            let path = try createLockFile(prefix: "kernel-contention")
            defer { cleanupLockFile(path) }

            let fd = try openForLock(path)
            var token = try Kernel.Lock.Token(
                descriptor: fd,
                range: .file,
                kind: .shared,
                acquire: .wait
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-shared", path, "--hold", "0", "--signal-ready"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = Swift.String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 0, "Helper should exit with 0 (success)")
            #expect(output.contains("READY"), "Helper should report READY")
            #expect(output.contains("RELEASED"), "Helper should report RELEASED")

            try token.release()
        }

        @Test
        func `shared lock blocks try-exclusive from another process`() throws {
            let path = try createLockFile(prefix: "kernel-contention")
            defer { cleanupLockFile(path) }

            let fd = try openForLock(path)
            var token = try Kernel.Lock.Token(
                descriptor: fd,
                range: .file,
                kind: .shared,
                acquire: .wait
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = Swift.String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }

        @Test
        func `non-overlapping byte ranges do not conflict`() throws {
            let path = try createLockFile(prefix: "kernel-contention")
            defer { cleanupLockFile(path) }

            let fd = try openForLock(path)
            var token = try Kernel.Lock.Token(
                descriptor: fd,
                range: .bytes(start: Kernel.File.Offset(0), end: Kernel.File.Offset(100)),
                kind: .exclusive,
                acquire: .wait
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path, "--range", "200-300", "--hold", "0", "--signal-ready"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = Swift.String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 0, "Helper should exit with 0 (success)")
            #expect(output.contains("READY"), "Helper should report READY")

            try token.release()
        }

        @Test
        func `overlapping byte ranges conflict`() throws {
            let path = try createLockFile(prefix: "kernel-contention")
            defer { cleanupLockFile(path) }

            let fd = try openForLock(path)
            var token = try Kernel.Lock.Token(
                descriptor: fd,
                range: .bytes(start: Kernel.File.Offset(0), end: Kernel.File.Offset(200)),
                kind: .exclusive,
                acquire: .wait
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.helperPath)
            process.arguments = ["try-exclusive", path, "--range", "100-300"]

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = Swift.String(data: outputData, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 1, "Helper should exit with 1 (would block)")
            #expect(output.contains("WOULD_BLOCK"), "Helper should report WOULD_BLOCK")

            try token.release()
        }
    }
#endif

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

/// Test support for cross-platform temporary file paths.

public import Kernel
import Strings

// Platform imports only for getpid/GetCurrentProcessId (acceptable in test support)
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    import WinSDK
#endif

extension Kernel {
    /// Namespace for temporary path operations in tests.
    public enum Temporary {}
}

extension Kernel.Temporary {
    /// Returns the system temp directory path.
    ///
    /// Uses platform-appropriate environment variables:
    /// - Unix: `TMPDIR`, falling back to "/tmp"
    /// - Windows: `TEMP` or `TMP`, falling back to "C:\Temp"
    public static var directory: Swift.String {
        #if os(Windows)
            if let temp = Kernel.Environment.get("TEMP") {
                return unsafe temp.withUnsafePointer { Swift.String(cString: $0) }
            }
            if let tmp = Kernel.Environment.get("TMP") {
                return unsafe tmp.withUnsafePointer { Swift.String(cString: $0) }
            }
            return "C:\\Temp"
        #else
            if let tmpdir = unsafe Kernel.Environment.get("TMPDIR") {
                return unsafe tmpdir.withUnsafePointer { Swift.String(cString: $0) }
            }
            return "/tmp"
        #endif
    }

    /// Generates a unique temporary file path.
    ///
    /// - Parameter prefix: Prefix for the filename (e.g., "kernel-test").
    /// - Returns: A unique path string in the system temp directory.
    public static func filePath(prefix: Swift.String) -> Swift.String {
        #if os(Windows)
            let pid = Int(GetCurrentProcessId())
        #else
            let pid = Int(getpid())
        #endif
        let random = Int.random(in: 0..<Int.max)
        let name = "\(prefix)-\(pid)-\(random)"

        #if os(Windows)
            return directory + "\\" + name
        #else
            return directory + "/" + name
        #endif
    }
}

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

@testable import Kernel
import SystemPackage

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

extension Kernel {
    /// Namespace for temporary path operations in tests.
    enum Temporary {}
}

extension Kernel.Temporary {
    #if os(Windows)
        /// Gets an environment variable using Windows API.
        private static func getEnvironmentVariable(_ name: String) -> String? {
            name.withCString(encodedAs: UTF16.self) { wName in
                // First call to get required buffer size
                let requiredSize = GetEnvironmentVariableW(wName, nil, 0)
                guard requiredSize > 0 else { return nil }

                // Allocate buffer and get the value
                var buffer = [WCHAR](repeating: 0, count: Int(requiredSize))
                let written = GetEnvironmentVariableW(wName, &buffer, requiredSize)
                guard written > 0 && written < requiredSize else { return nil }

                return String(decodingCString: buffer, as: UTF16.self)
            }
        }
    #endif

    /// Returns the system temp directory path.
    ///
    /// Uses platform-appropriate environment variables:
    /// - Unix: `TMPDIR`, falling back to "/tmp"
    /// - Windows: `TEMP` or `TMP`, falling back to "C:\Temp"
    static var directory: FilePath {
        #if os(Windows)
            if let temp = getEnvironmentVariable("TEMP") {
                return FilePath(temp)
            } else if let tmp = getEnvironmentVariable("TMP") {
                return FilePath(tmp)
            } else {
                return FilePath("C:\\Temp")
            }
        #else
            if let ptr = getenv("TMPDIR") {
                return FilePath(String(cString: ptr))
            } else {
                return FilePath("/tmp")
            }
        #endif
    }

    /// Generates a unique temporary file path.
    ///
    /// - Parameter prefix: Prefix for the filename (e.g., "kernel-test").
    /// - Returns: A unique FilePath in the system temp directory.
    static func filePath(prefix: String) -> FilePath {
        #if os(Windows)
            let pid = Int(GetCurrentProcessId())
        #else
            let pid = Int(getpid())
        #endif
        let random = Int.random(in: 0..<Int.max)
        let name = "\(prefix)-\(pid)-\(random)"

        #if os(Windows)
            return FilePath(directory.string + "\\" + name)
        #else
            return FilePath(directory.string + "/" + name)
        #endif
    }
}

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
    internal import Darwin
    internal import CDarwinShim
    internal import CPosixShim
#elseif canImport(Glibc)
    internal import Glibc
    internal import CPosixShim
#elseif canImport(Musl)
    internal import Musl
    internal import CPosixShim
#endif

extension Kernel.Process {
    /// Execute operations namespace.
    public enum Execute {}
}

// MARK: - Execute Operation

extension Kernel.Process.Execute {
    /// Replaces current process image with a new program.
    ///
    /// - Parameters:
    ///   - path: Path to the executable (null-terminated C string).
    ///   - argv: Argument vector (null-terminated array of C strings).
    ///   - envp: Environment vector (null-terminated array of C strings).
    /// - Throws: `Kernel.Process.Error.execute` (only returns on failure).
    ///
    /// ## Important
    ///
    /// This function does NOT return on success. The process image is replaced.
    ///
    /// ## Common Errors
    ///
    /// - ENOENT: File not found.
    /// - EACCES: Permission denied.
    /// - ENOEXEC: Invalid executable format.
    /// - ENOMEM: Insufficient memory.
    /// - E2BIG: Argument list too long.
    ///
    /// ## Memory Requirements
    ///
    /// - `argv` and `envp` MUST be null-terminated arrays of pointers.
    /// - Each element points to a null-terminated C string.
    /// - Caller owns all memory until the call completes.
    /// - On success, the process image is replaced (memory is irrelevant).
    /// - On failure, memory ownership returns to caller.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// switch try Kernel.Process.Fork.fork() {
    /// case .child:
    ///     "/bin/ls".withCString { path in
    ///         let argv: [UnsafePointer<CChar>?] = [path, nil]
    ///         let envp: [UnsafePointer<CChar>?] = [nil]
    ///         argv.withUnsafeBufferPointer { argvBuf in
    ///             envp.withUnsafeBufferPointer { envpBuf in
    ///                 try? Kernel.Process.Execute.execve(
    ///                     path: path,
    ///                     argv: argvBuf.baseAddress!,
    ///                     envp: envpBuf.baseAddress!
    ///                 )
    ///             }
    ///         }
    ///     }
    ///     Kernel.Process.Exit.now(127) // execute failed
    /// case .parent(let child):
    ///     let result = try Kernel.Process.Wait.wait(.process(child))
    /// }
    /// ```
    public static func execve(
        path: UnsafePointer<CChar>,
        argv: UnsafePointer<UnsafePointer<CChar>?>,
        envp: UnsafePointer<UnsafePointer<CChar>?>
    ) throws(Kernel.Process.Error) {
        // execve only returns on failure
        #if canImport(Darwin)
            _ = swift_execve(path, argv, envp)
        #elseif canImport(Glibc)
            _ = swift_execve(path, argv, envp)
        #elseif canImport(Musl)
            _ = Musl.execve(path, argv, envp)
        #endif
        throw .execute(.captureErrno())
    }
}


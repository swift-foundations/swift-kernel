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

public import Kernel_Primitives

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
internal import WinSDK
#endif

// MARK: - Core Streaming Write API

extension Kernel.File.Write.Streaming {
    /// Writes a sequence of byte chunks to a file path.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    ///
    /// - Parameters:
    ///   - chunkS: Swift.Sequence of owned byte arrays to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `Kernel.File.Write.Streaming.Error` on failure
    public static func write<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        to path: borrowing Kernel.Path.View,
        options: Options = Options()
    ) throws(Error) where Chunks.Element == [UInt8] {
        let pathString = Swift.String(path)
        let context = try open(pathString: pathString, options: options)

        do {
            for chunk in chunks {
                try writeAll(chunk.span, to: context.descriptor, pathString: context.tempPathString ?? context.resolvedPathString)
            }
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }

    /// Writes a single byte array to a file path.
    ///
    /// - Parameters:
    ///   - bytes: Bytes to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `Kernel.File.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: [UInt8],
        to path: borrowing Kernel.Path.View,
        options: Options = Options()
    ) throws(Error) {
        let pathString = Swift.String(path)
        let context = try open(pathString: pathString, options: options)
        do {
            try write(chunk: bytes.span, to: context)
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }

    /// Writes a span of bytes to a file path (zero-copy).
    ///
    /// - Parameters:
    ///   - bytes: Span of bytes to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `Kernel.File.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: borrowing Span<UInt8>,
        to path: borrowing Kernel.Path.View,
        options: Options = Options()
    ) throws(Error) {
        let pathString = Swift.String(path)
        let context = try open(pathString: pathString, options: options)
        do {
            try write(chunk: bytes, to: context)
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }
}

// MARK: - Reusable-Buffer Streaming API

extension Kernel.File.Write.Streaming {
    /// Streams data to a file using a caller-owned reusable buffer.
    ///
    /// This is the **performance-grade** streaming API. It guarantees no allocations
    /// in the write hot loop by requiring the caller to provide a fixed-capacity buffer.
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options
    ///   - buffer: Caller-owned buffer (pre-sized to desired chunk size)
    ///   - fill: Closure that fills the buffer and returns number of valid bytes.
    ///           Return 0 to signal completion.
    /// - Throws: `Kernel.File.Write.Streaming.Error` on failure
    public static func write(
        to path: borrowing Kernel.Path.View,
        options: Options = Options(),
        using buffer: inout [UInt8],
        fill: (inout [UInt8]) throws -> Int
    ) throws(Error) {
        let pathString = Swift.String(path)
        let context = try open(pathString: pathString, options: options)
        var writeError: Error? = nil

        defer {
            if writeError != nil {
                cleanup(context)
            }
        }

        while true {
            let bytesProduced: Int
            do {
                bytesProduced = try fill(&buffer)
            } catch {
                writeError = .userError(message: Swift.String(describing: error))
                throw writeError!
            }

            if bytesProduced == 0 {
                break
            }

            guard bytesProduced <= buffer.count else {
                writeError = .invalidFillResult(produced: bytesProduced, capacity: buffer.count)
                throw writeError!
            }

            do {
                try buffer.withUnsafeBufferPointer { ptr throws(Error) in
                    guard let base = ptr.baseAddress else { return }
                    let rawBuffer = UnsafeRawBufferPointer(start: base, count: bytesProduced)
                    try writeAllRaw(rawBuffer, to: context.descriptor, pathString: context.tempPathString ?? context.resolvedPathString)
                }
            } catch let error {
                writeError = error
                throw error
            }
        }

        do {
            try commit(context)
        } catch let error {
            writeError = error
            throw error
        }
    }
}

// MARK: - Multi-Phase API

extension Kernel.File.Write.Streaming {
    /// Opens a file for multi-phase streaming write.
    ///
    /// Returns a context that can be used for subsequent write(chunk:) and commit calls.
    public static func open(
        path: borrowing Kernel.Path.View,
        options: Options
    ) throws(Error) -> Context {
        try open(pathString: Swift.String(path), options: options)
    }

    /// Opens a file for multi-phase streaming write using a path string.
    ///
    /// Internal entry point that works with path strings directly.
    @usableFromInline
    internal static func open(
        pathString: Swift.String,
        options: Options
    ) throws(Error) -> Context {
        let (resolvedPath, parent) = resolvePaths(pathString)

        // Verify or create parent directory
        try verifyOrCreateParent(parent, createIntermediates: options.createIntermediates)

        switch options.commit {
        case .atomic(let atomicOptions):
            let tempPath = try generateTempPath(in: parent, for: resolvedPath)
            let fd = try createFile(at: tempPath, exclusive: true)
            return Context(
                descriptor: fd,
                tempPathString: tempPath,
                resolvedPathString: resolvedPath,
                parentPathString: parent,
                durability: atomicOptions.durability,
                isAtomic: true,
                strategy: atomicOptions.strategy
            )

        case .direct(let directOptions):
            // For direct mode with .create strategy, check existence first
            if case .create = directOptions.strategy {
                if fileExists(resolvedPath) {
                    throw .destinationExists(path: resolvedPath)
                }
            }
            let fd = try createFile(at: resolvedPath, exclusive: directOptions.strategy == .create)
            return Context(
                descriptor: fd,
                tempPathString: nil,
                resolvedPathString: resolvedPath,
                parentPathString: parent,
                durability: directOptions.durability,
                isAtomic: false,
                strategy: nil
            )
        }
    }

    /// Writes a chunk to an open streaming context.
    public static func write(
        chunk span: borrowing Span<UInt8>,
        to context: borrowing Context
    ) throws(Error) {
        try writeAll(span, to: context.descriptor, pathString: context.tempPathString ?? context.resolvedPathString)
    }

    /// Writes a raw buffer chunk to an open streaming context.
    public static func writeRaw(
        chunk buffer: UnsafeRawBufferPointer,
        to context: borrowing Context
    ) throws(Error) {
        try writeAllRaw(buffer, to: context.descriptor, pathString: context.tempPathString ?? context.resolvedPathString)
    }

    /// Commits a streaming write, closing the file and performing the atomic rename if needed.
    public static func commit(
        _ context: borrowing Context
    ) throws(Error) {
        // Sync file data
        try syncFile(context.descriptor, durability: context.durability)

        // Close the file descriptor
        try closeFile(context.descriptor)

        if context.isAtomic, let tempPath = context.tempPathString {
            // Atomic rename
            switch context.strategy {
            case .replaceExisting, .none:
                try atomicRename(from: tempPath, to: context.resolvedPathString)
            case .noClobber:
                try atomicRenameNoClobber(from: tempPath, to: context.resolvedPathString)
            }

            // Directory sync after publish - only for .full durability
            if context.durability == .full {
                do {
                    try syncDirectory(context.parentPathString)
                } catch let syncError {
                    if case .directorySyncFailed(let path, let code, let msg) = syncError {
                        throw .directorySyncFailedAfterCommit(path: path, code: code, message: msg)
                    }
                    throw syncError
                }
            }
        }
    }

    /// Cleans up a failed streaming write.
    ///
    /// Best-effort cleanup - closes fd and removes temp file if atomic mode.
    public static func cleanup(_ context: borrowing Context) {
        // Close fd if still open (ignore errors)
        try? Kernel.Close.close(context.descriptor)

        // Remove temp file if atomic mode
        if let tempPath = context.tempPathString {
            try? Kernel.Path.scope(tempPath) { kernelPath in
                try? Kernel.File.Delete.delete(kernelPath)
            }
        }
    }
}

// MARK: - Path Resolution

extension Kernel.File.Write.Streaming {
    /// Resolves paths and extracts parent directory.
    private static func resolvePaths(_ pathString: Swift.String) -> (resolved: Swift.String, parent: Swift.String) {
        #if os(Windows)
        let resolved = normalizeWindowsPath(pathString)
        let parent = windowsParentDirectory(of: resolved)
        #else
        let resolved = pathString
        let parent = posixParentDirectory(of: resolved)
        #endif
        return (resolved, parent)
    }

    #if os(Windows)
    private static func normalizeWindowsPath(_ path: Swift.String) -> Swift.String {
        var result: Swift.String = ""
        result.reserveCapacity(path.utf8.count)
        for char in path {
            if char == "/" {
                result.append("\\")
            } else {
                result.append(char)
            }
        }
        while result.count > 3 && result.hasSuffix("\\") {
            result.removeLast()
        }
        return result
    }

    private static func windowsParentDirectory(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "\\") {
            if lastSep == path.startIndex {
                return Swift.String(path[...lastSep])
            }
            let prefix = Swift.String(path[..<lastSep])
            if prefix.count == 2 && prefix.last == ":" {
                return prefix + "\\"
            }
            return prefix
        }
        return "."
    }
    #else
    private static func posixParentDirectory(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "/") {
            if lastSep == path.startIndex {
                return "/"
            }
            return Swift.String(path[..<lastSep])
        }
        return "."
    }
    #endif
}

// MARK: - File Operations

extension Kernel.File.Write.Streaming {
    private static func verifyOrCreateParent(
        _ path: Swift.String,
        createIntermediates: Bool
    ) throws(Error) {
        // Check if parent exists
        if fileExists(path) {
            return
        }

        if !createIntermediates {
            throw .parentVerificationFailed(
                path: path,
                code: .POSIX.ENOENT,
                message: "Parent directory does not exist"
            )
        }

        // Create parent directories recursively
        try createDirectories(path)
    }

    private static func createDirectories(_ path: Swift.String) throws(Error) {
        try? Kernel.Path.scope(path) { kernelPath in
            do {
                try Kernel.Directory.Create.create(kernelPath, permissions: .standard)
            } catch {
                // Ignore - directory might already exist
            }
        }
    }

    private static func fileExists(_ pathString: Swift.String) -> Bool {
        (try? Kernel.Path.scope(pathString) { kernelPath -> Bool in
            do {
                _ = try Kernel.File.Stats.lget(path: kernelPath)
                return true
            } catch {
                return false
            }
        }) ?? false
    }

    private static func createFile(
        at pathString: Swift.String,
        exclusive: Bool
    ) throws(Error) -> Kernel.Descriptor {
        var options: Kernel.File.Open.Options = [.create, .execClose]
        if exclusive {
            options.insert(.exclusive)
        } else {
            options.insert(.truncate)
        }

        do {
            return try Kernel.Path.scope(pathString) { kernelPath throws(Error) -> Kernel.Descriptor in
                do {
                    return try Kernel.File.Open.open(
                        path: kernelPath,
                        mode: .write,
                        options: options,
                        permissions: .standard
                    )
                } catch {
                    throw .fileCreationFailed(
                        path: pathString,
                        code: .POSIX.ENOENT,
                        message: "open failed: \(error)"
                    )
                }
            }
        } catch {
            if let bodyError = error.body {
                throw bodyError
            }
            throw .fileCreationFailed(
                path: pathString,
                code: .POSIX.ENOENT,
                message: "path conversion failed: \(error)"
            )
        }
    }

    private static func generateTempPath(
        in parent: Swift.String,
        for dest: Swift.String
    ) throws(Error) -> Swift.String {
        let baseName = fileName(of: dest)
        let random = try randomToken(length: 12)
        #if os(Windows)
        return "\(parent)\\\(baseName).streaming.\(random).tmp"
        #else
        return "\(parent)/.\(baseName).streaming.\(random).tmp"
        #endif
    }

    #if os(Windows)
    private static func fileName(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "\\") {
            return Swift.String(path[path.index(after: lastSep)...])
        }
        return path
    }
    #else
    private static func fileName(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "/") {
            return Swift.String(path[path.index(after: lastSep)...])
        }
        return path
    }
    #endif

    private static func randomToken(length: Int) throws(Error) -> Swift.String {
        let result = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer -> Swift.String in
            let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
            #if canImport(Darwin)
            unsafe Kernel.Random.fill(rawBuffer)
            #else
            do {
                try unsafe Kernel.Random.fill(rawBuffer)
            } catch {
                // Return empty on error - will be caught by validation
                return ""
            }
            #endif
            return hexEncode(Array(buffer))
        }

        if result.isEmpty {
            throw .randomGenerationFailed(code: .POSIX.EIO, message: "CSPRNG syscall failed")
        }
        return result
    }

    /// Simple hex encoding for random bytes.
    private static func hexEncode(_ bytes: [UInt8]) -> Swift.String {
        let hexChars: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
        var result = Swift.String()
        result.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            result.append(hexChars[Int(byte >> 4)])
            result.append(hexChars[Int(byte & 0x0F)])
        }
        return result
    }
}

// MARK: - Write Operations

extension Kernel.File.Write.Streaming {
    /// Writes all bytes to fd, handling partial writes.
    internal static func writeAll(
        _ span: borrowing Span<UInt8>,
        to fd: Kernel.Descriptor,
        pathString: Swift.String
    ) throws(Error) {
        let total = span.count
        if total == 0 { return }

        var written = 0

        try span.withUnsafeBufferPointer { buffer throws(Error) in
            guard let base = buffer.baseAddress else { return }

            while written < total {
                let remaining = total - written
                let slice = UnsafeRawBufferPointer(
                    start: base.advanced(by: written),
                    count: remaining
                )

                do {
                    let rc = try Kernel.IO.Write.write(fd, from: slice)
                    if rc > 0 {
                        written += rc
                        continue
                    }
                    if rc == 0 {
                        throw Error.writeFailed(
                            path: pathString,
                            bytesWritten: written,
                            code: .POSIX.EIO,
                            message: "write returned 0"
                        )
                    }
                } catch let error as Kernel.IO.Write.Error {
                    if case .blocking(.wouldBlock) = error {
                        continue
                    }
                    throw Error.writeFailed(
                        path: pathString,
                        bytesWritten: written,
                        code: .POSIX.EIO,
                        message: "write failed: \(error)"
                    )
                } catch {
                    throw Error.writeFailed(
                        path: pathString,
                        bytesWritten: written,
                        code: .POSIX.EIO,
                        message: "write failed: \(error)"
                    )
                }
            }
        }
    }

    /// Writes all bytes from a raw buffer to fd, handling partial writes.
    internal static func writeAllRaw(
        _ buffer: UnsafeRawBufferPointer,
        to fd: Kernel.Descriptor,
        pathString: Swift.String
    ) throws(Error) {
        let total = buffer.count
        if total == 0 { return }

        guard let base = buffer.baseAddress else { return }

        var written = 0

        while written < total {
            let remaining = total - written
            let slice = UnsafeRawBufferPointer(
                start: base.advanced(by: written),
                count: remaining
            )

            do {
                let rc = try Kernel.IO.Write.write(fd, from: slice)
                if rc > 0 {
                    written += rc
                    continue
                }
                if rc == 0 {
                    throw Error.writeFailed(
                        path: pathString,
                        bytesWritten: written,
                        code: .POSIX.EIO,
                        message: "write returned 0"
                    )
                }
            } catch let error as Kernel.IO.Write.Error {
                if case .blocking(.wouldBlock) = error {
                    continue
                }
                throw Error.writeFailed(
                    path: pathString,
                    bytesWritten: written,
                    code: .POSIX.EIO,
                    message: "write failed: \(error)"
                )
            } catch {
                throw Error.writeFailed(
                    path: pathString,
                    bytesWritten: written,
                    code: .POSIX.EIO,
                    message: "write failed: \(error)"
                )
            }
        }
    }
}

// MARK: - Sync and Close

extension Kernel.File.Write.Streaming {
    private static func syncFile(
        _ fd: Kernel.Descriptor,
        durability: Durability
    ) throws(Error) {
        switch durability {
        case .full, .dataOnly:
            do {
                try Kernel.File.Flush.flush(fd)
            } catch {
                throw .syncFailed(code: .POSIX.EIO, message: "fsync failed: \(error)")
            }
        case .none:
            break
        }
    }

    private static func closeFile(_ fd: Kernel.Descriptor) throws(Error) {
        do {
            try Kernel.Close.close(fd)
        } catch {
            throw .closeFailed(code: .POSIX.EIO, message: "close failed: \(error)")
        }
    }
}

// MARK: - Rename Operations

extension Kernel.File.Write.Streaming {
    private static func atomicRename(
        from source: Swift.String,
        to dest: Swift.String
    ) throws(Error) {
        try? Kernel.Path.scope(source, dest) { sourcePath, destPath in
            do {
                try Kernel.File.Move.move(from: sourcePath, to: destPath)
            } catch {
                // Error will be thrown below
            }
        }
        // Check if rename succeeded by verifying dest exists
        if !fileExists(dest) {
            throw .renameFailed(
                from: source,
                to: dest,
                code: .POSIX.EIO,
                message: "rename failed"
            )
        }
    }

    private static func atomicRenameNoClobber(
        from source: Swift.String,
        to dest: Swift.String
    ) throws(Error) {
        // Check if destination exists first
        if fileExists(dest) {
            throw .destinationExists(path: dest)
        }

        try? Kernel.Path.scope(source, dest) { sourcePath, destPath in
            do {
                try Kernel.File.Move.noClobber(from: sourcePath, to: destPath)
            } catch let error as Kernel.File.Move.Extended.Error {
                switch error {
                case .exists:
                    // Will be caught as destinationExists
                    break
                default:
                    break
                }
            } catch {
                // Continue and check result
            }
        }

        // Verify the move succeeded
        if !fileExists(dest) || fileExists(source) {
            if fileExists(dest) {
                throw .destinationExists(path: dest)
            }
            throw .renameFailed(
                from: source,
                to: dest,
                code: .POSIX.EIO,
                message: "noClobber rename failed"
            )
        }
    }

    private static func syncDirectory(_ pathString: Swift.String) throws(Error) {
        #if os(Windows)
        // No-op on Windows - MOVEFILE_WRITE_THROUGH provides durability
        _ = pathString
        #else
        // Open directory for read-only access to sync it
        let fd: Kernel.Descriptor
        do {
            fd = try Kernel.Path.scope(pathString) { kernelPath throws -> Kernel.Descriptor in
                try Kernel.File.Open.open(
                    path: kernelPath,
                    mode: .read,
                    options: [.execClose],
                    permissions: .none
                )
            }
        } catch {
            throw .directorySyncFailed(
                path: pathString,
                code: .POSIX.EIO,
                message: "open directory failed: \(error)"
            )
        }

        defer { try? Kernel.Close.close(fd) }

        do {
            try Kernel.File.Flush.flush(fd)
        } catch {
            throw .directorySyncFailed(
                path: pathString,
                code: .POSIX.EIO,
                message: "fsync directory failed: \(error)"
            )
        }
        #endif
    }
}

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

// MARK: - Core API

extension Kernel.File.Write.Atomic {
    /// Atomically writes bytes to a file path.
    ///
    /// This is the core primitive - all other write operations compose on top of this.
    ///
    /// ## Guarantees
    /// - Either the file exists with complete contents, or the original state is preserved
    /// - On success, data is synced to physical storage (survives power loss)
    /// - Safe to call concurrently for different paths
    ///
    /// ## Requirements
    /// - Parent directory must exist and be writable
    ///
    /// - Parameters:
    ///   - bytes: The data to write (borrowed, zero-copy)
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `Kernel.File.Write.Atomic.Error` on failure
    public static func write(
        _ bytes: borrowing Span<UInt8>,
        to path: borrowing Kernel.Path,
        options: borrowing Options = Options()
    ) throws(Error) {
        let pathString = Swift.String(path)
        try write(bytes, toPathString: pathString, options: options)
    }

    /// Internal entry point that works with path strings directly.
    internal static func write(
        _ bytes: borrowing Span<UInt8>,
        toPathString pathString: Swift.String,
        options: borrowing Options
    ) throws(Error) {
        typealias Phase = Kernel.File.Write.Atomic.Commit.Phase

        // Track progress for cleanup and error diagnostics
        var phase: Phase = .pending

        // 1. Resolve and validate paths
        let (resolved, parent) = resolvePaths(pathString)

        // Verify or create parent directory
        try verifyOrCreateParent(parent, createIntermediates: options.createIntermediates)

        // 2. Stat destination if it exists (for metadata preservation)
        let destStats = try statIfExists(resolved)

        // 3. Create temp file with unique name
        let (descriptor, tempPath) = try createTempFileWithRetry(in: parent, for: resolved)
        phase = .writing

        defer {
            // CRITICAL: After renamedPublished, NEVER unlink destination!
            // Only cleanup temp file if rename hasn't happened yet.
            if phase < .closed {
                try? Kernel.Close.close(descriptor)
            }
            if phase < .renamedPublished {
                try? Kernel.Path.scope(tempPath) { kernelPath in
                    try? Kernel.File.Delete.delete(kernelPath)
                }
            }
        }

        // 4. Write all data
        try writeAll(bytes, to: descriptor, pathString: tempPath)

        // 5. Sync file to disk
        try syncFile(descriptor, durability: options.durability)
        phase = .syncedFile

        // 6. Apply metadata from destination if requested
        if let stats = destStats {
            try applyMetadata(from: stats, to: descriptor, options: options, destPath: resolved)
        }

        // 7. Close file (required before rename on some systems)
        try closeFile(descriptor)
        phase = .closed

        // 8. Atomic rename
        switch options.strategy {
        case .replaceExisting:
            try atomicRename(from: tempPath, to: resolved)
        case .noClobber:
            try atomicRenameNoClobber(from: tempPath, to: resolved)
        }
        // CRITICAL: Update phase IMMEDIATELY after successful rename
        phase = .renamedPublished

        // 9. Sync directory to persist the rename - only for .full durability
        if options.durability == .full {
            phase = .directorySyncAttempted
            do {
                try syncDirectory(parent)
                phase = .syncedDirectory
            } catch let syncError {
                if case .directorySyncFailed(let path, let code, let msg) = syncError {
                    throw .directorySyncFailedAfterCommit(path: path, code: code, message: msg)
                }
                throw syncError
            }
        } else {
            phase = .syncedDirectory
        }
    }
}

// MARK: - Path Resolution

extension Kernel.File.Write.Atomic {
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

    private static func fileName(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "\\") {
            return Swift.String(path[path.index(after: lastSep)...])
        }
        return path
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

    private static func fileName(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "/") {
            return Swift.String(path[path.index(after: lastSep)...])
        }
        return path
    }
    #endif
}

// MARK: - Parent Directory Operations

extension Kernel.File.Write.Atomic {
    private static func verifyOrCreateParent(
        _ path: Swift.String,
        createIntermediates: Bool
    ) throws(Error) {
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
}

// MARK: - Temp File Creation

extension Kernel.File.Write.Atomic {
    /// Maximum attempts for temp file creation.
    private static let maxTempFileAttempts = 64

    private static func createTempFileWithRetry(
        in parent: Swift.String,
        for dest: Swift.String
    ) throws(Error) -> (descriptor: Kernel.Descriptor, tempPath: Swift.String) {
        let baseName = fileName(of: dest)
        let pid = Kernel.Process.ID.current.rawValue

        for attempt in 0..<maxTempFileAttempts {
            let random = try randomToken(length: 12)
            #if os(Windows)
            let tempPath = "\(parent)\\\(baseName).atomic.\(pid).\(random).tmp"
            #else
            let tempPath = "\(parent)/.\(baseName).atomic.\(pid).\(random).tmp"
            #endif

            let result: Result<Kernel.Descriptor, Swift.Error>
            do {
                result = try Kernel.Path.scope(tempPath) { kernelPath -> Result<Kernel.Descriptor, Swift.Error> in
                    do {
                        let fd = try Kernel.File.Open.open(
                            path: kernelPath,
                            mode: .readWrite,
                            options: [.create, .exclusive],
                            permissions: Kernel.File.Permissions(rawValue: 0o600)
                        )
                        return .success(fd)
                    } catch {
                        return .failure(error)
                    }
                }
            } catch {
                throw .tempFileCreationFailed(
                    directory: parent,
                    code: .POSIX.ENOENT,
                    message: "path conversion failed: \(error)"
                )
            }

            switch result {
            case .success(let fd):
                return (fd, tempPath)
            case .failure(let error):
                if let openError = error as? Kernel.File.Open.Error {
                    if case .path(.exists) = openError, attempt < maxTempFileAttempts - 1 {
                        continue
                    }
                    throw .tempFileCreationFailed(
                        directory: parent,
                        code: .POSIX.EIO,
                        message: "\(openError)"
                    )
                }
                throw .tempFileCreationFailed(
                    directory: parent,
                    code: .POSIX.EIO,
                    message: "open failed: \(error)"
                )
            }
        }

        throw .tempFileCreationFailed(
            directory: parent,
            code: .EEXIST,
            message: "Failed after \(maxTempFileAttempts) attempts"
        )
    }

    private static func randomToken(length: Int) throws(Error) -> Swift.String {
        let result = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer -> Swift.String in
            let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
            #if canImport(Darwin)
            unsafe Kernel.Random.fill(rawBuffer)
            #else
            do {
                try unsafe Kernel.Random.fill(rawBuffer)
            } catch {
                return ""
            }
            #endif
            return hexEncode(Array(buffer))
        }

        if result.isEmpty {
            throw .randomGenerationFailed(code: .POSIX.EIO, operation: "getrandom", message: "CSPRNG syscall failed")
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

// MARK: - File Stats

extension Kernel.File.Write.Atomic {
    private static func statIfExists(_ pathString: Swift.String) throws(Error) -> Kernel.File.Stats? {
        return (try? Kernel.Path.scope(pathString) { kernelPath -> Kernel.File.Stats? in
            do {
                return try Kernel.File.Stats.lget(path: kernelPath)
            } catch {
                return nil
            }
        }) ?? nil
    }
}

// MARK: - Write Operations

extension Kernel.File.Write.Atomic {
    private static func writeAll(
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
                            bytesWritten: written,
                            bytesExpected: total,
                            code: .POSIX.EIO,
                            message: "write returned 0"
                        )
                    }
                } catch let error as Kernel.IO.Write.Error {
                    if case .blocking(.wouldBlock) = error {
                        continue
                    }
                    throw Error.writeFailed(
                        bytesWritten: written,
                        bytesExpected: total,
                        code: .POSIX.EIO,
                        message: "write failed: \(error)"
                    )
                } catch {
                    throw Error.writeFailed(
                        bytesWritten: written,
                        bytesExpected: total,
                        code: .POSIX.EIO,
                        message: "write failed: \(error)"
                    )
                }
            }
        }
    }
}

// MARK: - Sync and Close

extension Kernel.File.Write.Atomic {
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

// MARK: - Atomic Rename

extension Kernel.File.Write.Atomic {
    private static func atomicRename(
        from source: Swift.String,
        to dest: Swift.String
    ) throws(Error) {
        try? Kernel.Path.scope(source, dest) { sourcePath, destPath in
            do {
                try Kernel.File.Move.move(from: sourcePath, to: destPath)
            } catch {
                // Error handled below
            }
        }
        // Verify rename succeeded
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
                    break // Will be caught below
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
        // No-op on Windows - NTFS provides reasonable guarantees
        _ = pathString
        #else
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

// MARK: - Metadata Preservation

extension Kernel.File.Write.Atomic {
    private static func applyMetadata(
        from stats: Kernel.File.Stats,
        to descriptor: Kernel.Descriptor,
        options: borrowing Options,
        destPath: Swift.String
    ) throws(Error) {
        // Permissions (mode)
        if options.preservePermissions {
            do {
                try Kernel.File.Attributes.setPermissions(descriptor, permissions: stats.permissions)
            } catch let error as Kernel.File.Attributes.Error {
                let code: Kernel.Error.Code
                switch error {
                case .platform(let e): code = e.code
                case .permission(_): code = .POSIX.EACCES
                case .path(_): code = .POSIX.ENOENT
                case .io(_): code = .POSIX.EIO
                }
                throw .metadataPreservationFailed(
                    operation: "fchmod",
                    code: code,
                    message: "\(error)"
                )
            }
        }

        // Ownership (uid/gid)
        if options.preserveOwnership {
            do {
                try Kernel.File.Chown.fchown(descriptor, uid: stats.uid, gid: stats.gid)
            } catch let error as Kernel.File.Chown.Error {
                // Ownership changes often fail for non-root users
                if options.strictOwnership {
                    let code: Kernel.Error.Code
                    switch error {
                    case .platform(let e): code = e.code
                    case .permission(_): code = .POSIX.EACCES
                    case .path(_): code = .POSIX.ENOENT
                    case .io(_): code = .POSIX.EIO
                    }
                    throw .metadataPreservationFailed(
                        operation: "fchown",
                        code: code,
                        message: "\(error)"
                    )
                }
                // Otherwise silently ignore - expected for normal users
            }
        }

        // Timestamps
        if options.preserveTimestamps {
            do {
                try Kernel.File.Times.setTimes(
                    descriptor,
                    accessTime: stats.accessTime,
                    modificationTime: stats.modificationTime
                )
            } catch let error as Kernel.File.Times.Error {
                throw .timestampPreservationFailed(error)
            }
        }

        // Extended attributes - skip for now (requires Darwin.Kernel.File.ExtendedAttributes)
        _ = options.preserveExtendedAttributes

        // ACLs - skip for now (requires separate shim)
        _ = options.preserveACLs
    }
}

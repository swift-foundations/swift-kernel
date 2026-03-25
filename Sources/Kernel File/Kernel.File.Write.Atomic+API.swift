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

// MARK: - Error Mapping

extension Kernel.File.Write.Atomic.Error {
    /// Creates an Atomic error from a shared write error.
    init(_ error: Kernel.File.Write.Error) {
        switch error {
        case .sync(let msg):
            self = .syncFailed(code: .POSIX.EIO, message: msg)
        case .close(let msg):
            self = .closeFailed(code: .POSIX.EIO, message: msg)
        case .rename(let from, let to, let msg):
            self = .renameFailed(from: from, to: to, code: .POSIX.EIO, message: msg)
        case .exists(let path):
            self = .destinationExists(path: path)
        case .directory(let path, let msg):
            self = .directorySyncFailed(path: path, code: .POSIX.EIO, message: msg)
        case .write(let written, let expected, let msg):
            self = .writeFailed(
                bytesWritten: written,
                bytesExpected: expected,
                code: .POSIX.EIO,
                message: msg
            )
        case .random(let msg):
            self = .randomGenerationFailed(
                code: .POSIX.EIO,
                operation: "getrandom",
                message: msg
            )
        }
    }
}

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
        to path: borrowing Kernel.Path.View,
        options: borrowing Options = Options()
    ) throws(Error) {
        try write(bytes, toPathString: Swift.String(path), options: options)
    }

    /// Internal entry point that works with path strings directly.
    internal static func write(
        _ bytes: borrowing Span<UInt8>,
        toPathString pathString: Swift.String,
        options: borrowing Options
    ) throws(Error) {
        typealias Phase = Kernel.File.Write.Atomic.Commit.Phase

        var phase: Phase = .pending

        // 1. Resolve and validate paths
        let (resolved, parent) = Kernel.File.Write.resolvePaths(pathString)

        if !Kernel.File.Write.fileExists(parent) {
            throw .parentVerificationFailed(
                path: parent,
                code: .POSIX.ENOENT,
                message: "Parent directory does not exist"
            )
        }

        // 2. Stat destination if it exists (for metadata preservation)
        let destStats = try statIfExists(resolved)

        // 3. Create temp file with unique name
        let (descriptor, tempPath) = try createTempFileWithRetry(
            in: parent,
            for: resolved
        )
        phase = .writing

        defer {
            // CRITICAL: After renamedPublished, NEVER unlink destination!
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
        do {
            try Kernel.File.Write.writeAll(bytes, to: descriptor)
        } catch { throw Error(error) }

        // 5. Sync file to disk
        do {
            try Kernel.File.Write.syncFile(
                descriptor,
                durability: options.durability
            )
        } catch { throw Error(error) }
        phase = .syncedFile

        // 6. Apply metadata from destination if requested
        if let stats = destStats {
            try applyMetadata(
                from: stats,
                to: descriptor,
                options: options,
                destPath: resolved
            )
        }

        // 7. Close file (required before rename on some systems)
        do {
            try Kernel.File.Write.closeFile(descriptor)
        } catch { throw Error(error) }
        phase = .closed

        // 8. Atomic rename
        switch options.strategy {
        case .replaceExisting:
            do {
                try Kernel.File.Write.atomicRename(
                    from: tempPath,
                    to: resolved
                )
            } catch { throw Error(error) }
        case .noClobber:
            do {
                try Kernel.File.Write.atomicRenameNoClobber(
                    from: tempPath,
                    to: resolved
                )
            } catch { throw Error(error) }
        }
        phase = .renamedPublished

        // 9. Sync directory to persist the rename
        if options.durability == .full {
            phase = .directorySyncAttempted
            do {
                try Kernel.File.Write.syncDirectory(parent)
                phase = .syncedDirectory
            } catch {
                if case .directory(let path, let msg) = error {
                    throw .directorySyncFailedAfterCommit(
                        path: path,
                        code: .POSIX.EIO,
                        message: msg
                    )
                }
                throw Error(error)
            }
        } else {
            phase = .syncedDirectory
        }
    }
}

// MARK: - File Stats

extension Kernel.File.Write.Atomic {
    private static func statIfExists(
        _ pathString: Swift.String
    ) throws(Error) -> Kernel.File.Stats? {
        return (try? Kernel.Path.scope(pathString) { kernelPath -> Kernel.File.Stats? in
            do {
                return try Kernel.File.Stats.lget(path: kernelPath)
            } catch {
                return nil
            }
        }) ?? nil
    }
}

// MARK: - Temp File Creation

extension Kernel.File.Write.Atomic {
    private static let maxTempFileAttempts = 64

    private static func createTempFileWithRetry(
        in parent: Swift.String,
        for dest: Swift.String
    ) throws(Error) -> (descriptor: Kernel.Descriptor, tempPath: Swift.String) {
        let baseName = Kernel.File.Write.fileName(of: dest)
        let pid = Kernel.Process.ID.current

        for attempt in 0..<maxTempFileAttempts {
            let random: Swift.String
            do {
                random = try Kernel.File.Write.randomToken(length: 12)
            } catch { throw Error(error) }
            #if os(Windows)
            let tempPath = "\(parent)\\\(baseName).atomic.\(pid).\(random).tmp"
            #else
            let tempPath = "\(parent)/.\(baseName).atomic.\(pid).\(random).tmp"
            #endif

            let result: Result<Kernel.Descriptor, any Swift.Error>
            do {
                result = try Kernel.Path.scope(tempPath) { kernelPath -> Result<Kernel.Descriptor, any Swift.Error> in
                    do {
                        let fd = try Kernel.File.Open.open(
                            path: kernelPath,
                            mode: .readWrite,
                            options: [.create, .exclusive],
                            permissions: .ownerReadWrite
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
                    if case .path(.exists) = openError,
                       attempt < maxTempFileAttempts - 1
                    {
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
}

// MARK: - Metadata Preservation

extension Kernel.File.Write.Atomic {
    private static func applyMetadata(
        from stats: Kernel.File.Stats,
        to descriptor: Kernel.Descriptor,
        options: borrowing Options,
        destPath: Swift.String
    ) throws(Error) {
        if options.preservation.contains(.permissions) {
            do {
                try Kernel.File.Attributes.setPermissions(
                    descriptor,
                    permissions: stats.permissions
                )
            } catch let error {
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

        if case .preserve(let strict) = options.ownership {
            do {
                try Kernel.File.Chown.fchown(
                    descriptor,
                    uid: stats.uid,
                    gid: stats.gid
                )
            } catch let error {
                if strict {
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
            }
        }

        if options.preservation.contains(.timestamps) {
            do {
                try Kernel.File.Times.setTimes(
                    descriptor,
                    accessTime: stats.accessTime,
                    modificationTime: stats.modificationTime
                )
            } catch let error {
                throw .timestampPreservationFailed(error)
            }
        }

        _ = options.preservation.contains(.extendedAttributes)
        _ = options.preservation.contains(.acls)
    }
}

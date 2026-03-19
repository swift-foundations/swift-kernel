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

extension Kernel.File.Write.Streaming.Error {
    /// Creates a Streaming error from a shared write error.
    init(_ error: Kernel.File.Write.Error) {
        switch error {
        case .sync(let msg):
            self = .syncFailed(code: .POSIX.EIO, message: msg)
        case .close(let msg):
            self = .closeFailed(code: .POSIX.EIO, message: msg)
        case .rename(let from, let to, let msg):
            self = .renameFailed(
                from: from,
                to: to,
                code: .POSIX.EIO,
                message: msg
            )
        case .exists(let path):
            self = .destinationExists(path: path)
        case .directory(let path, let msg):
            self = .directorySyncFailed(
                path: path,
                code: .POSIX.EIO,
                message: msg
            )
        case .write(let written, _, let msg):
            self = .writeFailed(
                path: "",
                bytesWritten: written,
                code: .POSIX.EIO,
                message: msg
            )
        case .random(let msg):
            self = .randomGenerationFailed(
                code: .POSIX.EIO,
                message: msg
            )
        }
    }
}

// MARK: - Core Streaming Write API

extension Kernel.File.Write.Streaming {
    /// Writes a sequence of byte chunks to a file path.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    public static func write<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        to path: borrowing Kernel.Path.View,
        options: Options = Options()
    ) throws(Error) where Chunks.Element == [UInt8] {
        let pathString = Swift.String(path)
        let context = try open(pathString: pathString, options: options)

        do {
            for chunk in chunks {
                try write(chunk: chunk.span, to: context)
            }
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }

    /// Writes a single byte array to a file path.
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
    public static func write<E: Swift.Error>(
        to path: borrowing Kernel.Path.View,
        options: Options = Options(),
        using buffer: inout [UInt8],
        fill: (inout [UInt8]) throws(E) -> Int
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
            do throws(E) {
                bytesProduced = try fill(&buffer)
            } catch {
                writeError = .userError(
                    message: Swift.String(describing: error)
                )
                throw writeError!
            }

            if bytesProduced == 0 {
                break
            }

            guard bytesProduced <= buffer.count else {
                writeError = .invalidFillResult(
                    produced: bytesProduced,
                    capacity: buffer.count
                )
                throw writeError!
            }

            do throws(Kernel.File.Write.Error) {
                try unsafe buffer.withUnsafeBufferPointer { ptr throws(Kernel.File.Write.Error) in
                    guard let base = ptr.baseAddress else { return }
                    try unsafe Kernel.File.Write.writeAllRaw(
                        unsafe UnsafeRawBufferPointer(
                            start: base,
                            count: bytesProduced
                        ),
                        to: context.descriptor
                    )
                }
            } catch let error {
                writeError = Error(error)
                throw writeError!
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
    public static func open(
        path: borrowing Kernel.Path.View,
        options: Options
    ) throws(Error) -> Context {
        try open(pathString: Swift.String(path), options: options)
    }

    @usableFromInline
    internal static func open(
        pathString: Swift.String,
        options: Options
    ) throws(Error) -> Context {
        let (resolvedPath, parent) = Kernel.File.Write.resolvePaths(pathString)

        if !Kernel.File.Write.fileExists(parent) {
            throw .parentVerificationFailed(
                path: parent,
                code: .POSIX.ENOENT,
                message: "Parent directory does not exist"
            )
        }

        switch options.commit {
        case .atomic(let atomicOptions):
            let tempPath = try generateTempPath(
                in: parent,
                for: resolvedPath
            )
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
            if case .create = directOptions.strategy {
                if Kernel.File.Write.fileExists(resolvedPath) {
                    throw .destinationExists(path: resolvedPath)
                }
            }
            let fd = try createFile(
                at: resolvedPath,
                exclusive: directOptions.strategy == .create
            )
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
        do {
            try Kernel.File.Write.writeAll(span, to: context.descriptor)
        } catch { throw Error(error) }
    }

    /// Writes a raw buffer chunk to an open streaming context.
    ///
    /// Distinguished from the `Span<UInt8>` overload by parameter type.
    public static func write(
        chunk buffer: UnsafeRawBufferPointer,
        to context: borrowing Context
    ) throws(Error) {
        do {
            try unsafe Kernel.File.Write.writeAllRaw(
                buffer,
                to: context.descriptor
            )
        } catch { throw Error(error) }
    }

    /// Commits a streaming write, closing the file and performing the atomic
    /// rename if needed.
    public static func commit(
        _ context: borrowing Context
    ) throws(Error) {
        do {
            try Kernel.File.Write.syncFile(
                context.descriptor,
                durability: context.durability.unified
            )
        } catch { throw Error(error) }

        do {
            try Kernel.File.Write.closeFile(context.descriptor)
        } catch { throw Error(error) }

        if context.isAtomic, let tempPath = context.tempPathString {
            switch context.strategy {
            case .replaceExisting, .none:
                do {
                    try Kernel.File.Write.atomicRename(
                        from: tempPath,
                        to: context.resolvedPathString
                    )
                } catch { throw Error(error) }
            case .noClobber:
                do {
                    try Kernel.File.Write.atomicRenameNoClobber(
                        from: tempPath,
                        to: context.resolvedPathString
                    )
                } catch { throw Error(error) }
            }

            if context.durability == .full {
                do {
                    try Kernel.File.Write.syncDirectory(
                        context.parentPathString
                    )
                } catch {
                    if case .directory(let path, let msg) = error {
                        throw Error.directorySyncFailedAfterCommit(
                            path: path,
                            code: .POSIX.EIO,
                            message: msg
                        )
                    }
                    throw Error(error)
                }
            }
        }
    }

    /// Cleans up a failed streaming write.
    public static func cleanup(_ context: borrowing Context) {
        try? Kernel.Close.close(context.descriptor)

        if let tempPath = context.tempPathString {
            try? Kernel.Path.scope(tempPath) { kernelPath in
                try? Kernel.File.Delete.delete(kernelPath)
            }
        }
    }
}

// MARK: - File Operations (Streaming-Specific)

extension Kernel.File.Write.Streaming {
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
        let baseName = Kernel.File.Write.fileName(of: dest)
        let random: Swift.String
        do {
            random = try Kernel.File.Write.randomToken(length: 12)
        } catch { throw Error(error) }
        #if os(Windows)
        return "\(parent)\\\(baseName).streaming.\(random).tmp"
        #else
        return "\(parent)/.\(baseName).streaming.\(random).tmp"
        #endif
    }
}

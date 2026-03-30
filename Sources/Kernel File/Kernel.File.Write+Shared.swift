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

internal import Kernel_Primitives

// MARK: - Path Resolution

extension Kernel.File.Write {
    internal static func resolvePaths(
        _ pathString: Swift.String
    ) -> (resolved: Swift.String, parent: Swift.String) {
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
    internal static func normalizeWindowsPath(_ path: Swift.String) -> Swift.String {
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

    internal static func windowsParentDirectory(
        of path: Swift.String
    ) -> Swift.String {
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

    internal static func fileName(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "\\") {
            return Swift.String(path[path.index(after: lastSep)...])
        }
        return path
    }
    #else
    internal static func posixParentDirectory(
        of path: Swift.String
    ) -> Swift.String {
        if let lastSep = path.lastIndex(of: "/") {
            if lastSep == path.startIndex {
                return "/"
            }
            return Swift.String(path[..<lastSep])
        }
        return "."
    }

    internal static func fileName(of path: Swift.String) -> Swift.String {
        if let lastSep = path.lastIndex(of: "/") {
            return Swift.String(path[path.index(after: lastSep)...])
        }
        return path
    }
    #endif
}

// MARK: - File Existence

extension Kernel.File.Write {
    internal static func fileExists(_ pathString: Swift.String) -> Bool {
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

// MARK: - Random Token

extension Kernel.File.Write {
    internal static func randomToken(
        length: Int
    ) throws(Kernel.File.Write.Error) -> Swift.String {
        let result = unsafe withUnsafeTemporaryAllocation(
            of: UInt8.self,
            capacity: length
        ) { buffer -> Swift.String in
            let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            unsafe Kernel.Random.fill(rawBuffer)
            #else
            do {
                try unsafe Kernel.Random.fill(rawBuffer)
            } catch {
                return ""
            }
            #endif
            return unsafe hexEncode(Array(buffer))
        }

        if result.isEmpty {
            throw .random("CSPRNG syscall failed")
        }
        return result
    }

    internal static func hexEncode(_ bytes: [UInt8]) -> Swift.String {
        let hexChars: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7",
            "8", "9", "a", "b", "c", "d", "e", "f",
        ]
        var result = Swift.String()
        result.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            result.append(hexChars[Int(byte >> 4)])
            result.append(hexChars[Int(byte & 0x0F)])
        }
        return result
    }
}

// MARK: - Write All

extension Kernel.File.Write {
    /// Writes all bytes from a span to a file descriptor, handling partial writes.
    internal static func writeAll(
        _ span: borrowing Span<UInt8>,
        to fd: borrowing Kernel.Descriptor
    ) throws(Kernel.File.Write.Error) {
        let total = span.count
        if total == 0 { return }

        var written = 0

        unsafe try span.withUnsafeBufferPointer { buffer throws(Kernel.File.Write.Error) in
            guard let base = buffer.baseAddress else { return }

            while written < total {
                let slice = unsafe UnsafeRawBufferPointer(
                    start: base.advanced(by: written),
                    count: total - written
                )

                do {
                    let rc = unsafe try Kernel.IO.Write.write(fd, from: slice)
                    if rc > 0 {
                        written += rc
                        continue
                    }
                    if rc == 0 {
                        throw Kernel.File.Write.Error.write(
                            written: written,
                            expected: total,
                            "write returned 0"
                        )
                    }
                } catch let error as Kernel.IO.Write.Error {
                    if case .blocking(.wouldBlock) = error { continue }
                    throw Kernel.File.Write.Error.write(
                        written: written,
                        expected: total,
                        "write failed: \(error)"
                    )
                } catch let error as Kernel.File.Write.Error {
                    throw error
                } catch {
                    throw Kernel.File.Write.Error.write(
                        written: written,
                        expected: total,
                        "write failed: \(error)"
                    )
                }
            }
        }
    }

    /// Writes all bytes from a raw buffer to a file descriptor, handling partial writes.
    internal static func writeAllRaw(
        _ buffer: UnsafeRawBufferPointer,
        to fd: borrowing Kernel.Descriptor
    ) throws(Kernel.File.Write.Error) {
        let total = buffer.count
        if total == 0 { return }

        guard let base = buffer.baseAddress else { return }

        var written = 0

        while written < total {
            let slice = unsafe UnsafeRawBufferPointer(
                start: base.advanced(by: written),
                count: total - written
            )

            do {
                let rc = unsafe try Kernel.IO.Write.write(fd, from: slice)
                if rc > 0 {
                    written += rc
                    continue
                }
                if rc == 0 {
                    throw Kernel.File.Write.Error.write(
                        written: written,
                        expected: total,
                        "write returned 0"
                    )
                }
            } catch let error as Kernel.IO.Write.Error {
                if case .blocking(.wouldBlock) = error { continue }
                throw Kernel.File.Write.Error.write(
                    written: written,
                    expected: total,
                    "write failed: \(error)"
                )
            } catch let error as Kernel.File.Write.Error {
                throw error
            } catch {
                throw Kernel.File.Write.Error.write(
                    written: written,
                    expected: total,
                    "write failed: \(error)"
                )
            }
        }
    }
}

// MARK: - Sync and Close

extension Kernel.File.Write {
    /// Syncs file data according to durability mode.
    ///
    /// - `.full`: fsync (or F_FULLFSYNC on Darwin)
    /// - `.dataOnly`: fdatasync on Linux, F_BARRIERFSYNC on Darwin, fsync elsewhere
    /// - `.none`: no-op
    internal static func syncFile(
        _ fd: borrowing Kernel.Descriptor,
        durability: Kernel.File.Write.Durability
    ) throws(Kernel.File.Write.Error) {
        switch durability {
        case .full:
            do {
                try Kernel.File.Flush.flush(fd)
            } catch {
                throw .sync("fsync failed: \(error)")
            }
        case .dataOnly:
            do {
                #if os(Linux)
                try POSIX.Kernel.File.Flush.data(fd)
                #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
                try POSIX.Kernel.File.Flush.barrier(fd)
                #else
                try Kernel.File.Flush.flush(fd)
                #endif
            } catch {
                throw .sync("data sync failed: \(error)")
            }
        case .none:
            break
        }
    }

    internal static func closeFile(
        _ fd: borrowing Kernel.Descriptor
    ) throws(Kernel.File.Write.Error) {
        do {
            try Kernel.Close.close(fd)
        } catch {
            throw .close("close failed: \(error)")
        }
    }
}

// MARK: - Rename Operations

extension Kernel.File.Write {
    /// Atomically renames a file, propagating the actual error on failure.
    internal static func atomicRename(
        from source: Swift.String,
        to dest: Swift.String
    ) throws(Kernel.File.Write.Error) {
        var moveError: (any Swift.Error)?

        do {
            try Kernel.Path.scope(source, dest) { sourcePath, destPath in
                do {
                    try Kernel.File.Move.move(from: sourcePath, to: destPath)
                } catch {
                    moveError = error
                }
            }
        } catch {
            throw .rename(
                from: source,
                to: dest,
                "path conversion failed: \(error)"
            )
        }

        if let error = moveError {
            throw .rename(from: source, to: dest, "\(error)")
        }
    }

    /// Atomically renames without overwriting.
    ///
    /// Uses the platform's native no-clobber rename
    /// (`renameat2(RENAME_NOREPLACE)` on Linux, `renamex_np(RENAME_EXCL)` on macOS).
    internal static func atomicRenameNoClobber(
        from source: Swift.String,
        to dest: Swift.String
    ) throws(Kernel.File.Write.Error) {
        var moveError: (any Swift.Error)?

        do {
            try Kernel.Path.scope(source, dest) { sourcePath, destPath in
                do {
                    try Kernel.File.Move.noClobber(from: sourcePath, to: destPath)
                } catch {
                    moveError = error
                }
            }
        } catch {
            throw .rename(
                from: source,
                to: dest,
                "path conversion failed: \(error)"
            )
        }

        if let error = moveError {
            if let extError = error as? Kernel.File.Move.Extended.Error,
               case .exists = extError
            {
                throw .exists(path: dest)
            }
            throw .rename(from: source, to: dest, "\(error)")
        }
    }

    /// Syncs a directory to persist rename operations.
    internal static func syncDirectory(
        _ pathString: Swift.String
    ) throws(Kernel.File.Write.Error) {
        #if os(Windows)
        _ = pathString
        #else
        // Open, flush, and close within the scope closure to avoid returning
        // ~Copyable Kernel.Descriptor through do-catch (compiler bug workaround).
        do {
            try Kernel.Path.scope(pathString) { kernelPath in
                let fd = try Kernel.File.Open.open(
                    path: kernelPath,
                    mode: .read,
                    options: [.execClose],
                    permissions: .none
                )
                defer { try? Kernel.Close.close(fd) }
                try Kernel.File.Flush.flush(fd)
            }
        } catch {
            throw .directory(
                path: pathString,
                "fsync directory failed: \(error)"
            )
        }
        #endif
    }
}

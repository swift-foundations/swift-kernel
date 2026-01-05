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
public import SystemPackage

// MARK: - High-Level Clone API

extension Kernel.File.Clone {
    /// Clones a file from source to destination.
    ///
    /// This is the primary entry point for file cloning. The behavior parameter
    /// controls whether to require reflink, allow fallback to copy, or skip
    /// reflink entirely.
    ///
    /// - Parameters:
    ///   - source: Path to the source file.
    ///   - destination: Path to the destination (must not exist).
    ///   - behavior: The cloning behavior policy.
    /// - Returns: The result indicating whether reflink or copy was used.
    /// - Throws: `Kernel.File.Clone.Error` if the operation fails.
    public static func clone(
        from source: FilePath,
        to destination: FilePath,
        behavior: Behavior
    ) throws(Error) -> Result {
        switch behavior {
        case .reflinkOrFail:
            return try cloneReflinkOnly(from: source, to: destination)
        case .reflinkOrCopy:
            return try cloneWithFallback(from: source, to: destination)
        case .copyOnly:
            try copyOnly(from: source, to: destination)
            return .copied
        }
    }
}

// MARK: - Internal Implementation

extension Kernel.File.Clone {
    /// Clones using reflink only; fails if unsupported.
    private static func cloneReflinkOnly(
        from source: FilePath,
        to destination: FilePath
    ) throws(Error) -> Result {
        #if os(macOS)
            do {
                let cloned = try Clonefile.attempt(
                    source: source,
                    destination: destination
                )
                if cloned {
                    return .reflinked
                }
                throw Error.notSupported
            } catch let error as Error.Syscall {
                throw Error(from: error)
            } catch let error as Error {
                throw error
            } catch {
                throw .notSupported
            }

        #elseif os(Linux)
            // On Linux, we need to open files to use FICLONE
            let srcDescriptor: Kernel.Descriptor
            do {
                srcDescriptor = try Kernel.File.Open.open(
                    path: source,
                    mode: .read,
                    options: [],
                    permissions: 0
                )
            } catch let error as Kernel.File.Open.Error {
                if case .path(.notFound) = error {
                    throw Error.sourceNotFound
                }
                throw Error.notSupported
            }
            defer { try? Kernel.Close.close(srcDescriptor) }

            // Create destination file
            let dstDescriptor: Kernel.Descriptor
            do {
                dstDescriptor = try Kernel.File.Open.open(
                    path: destination,
                    mode: .write,
                    options: [.create, .exclusive],
                    permissions: 0o644
                )
            } catch let error as Kernel.File.Open.Error {
                if case .path(.exists) = error {
                    throw Error.destinationExists
                }
                throw Error.notSupported
            }
            defer { try? Kernel.Close.close(dstDescriptor) }

            do {
                let cloned = try Ficlone.attempt(
                    source: srcDescriptor,
                    destination: dstDescriptor
                )
                if cloned {
                    return .reflinked
                }
                try? Kernel.Unlink.unlink(destination)
                throw Error.notSupported
            } catch let error as Error.Syscall {
                try? Kernel.Unlink.unlink(destination)
                throw Error(from: error)
            } catch let error as Error {
                try? Kernel.Unlink.unlink(destination)
                throw error
            } catch {
                try? Kernel.Unlink.unlink(destination)
                throw .notSupported
            }

        #elseif os(Windows)
            throw Error.notSupported

        #else
            throw Error.notSupported
        #endif
    }

    /// Clones using reflink if available, falls back to copy.
    private static func cloneWithFallback(
        from source: FilePath,
        to destination: FilePath
    ) throws(Error) -> Result {
        #if os(macOS)
            // First try pure clonefile
            var cloned = false
            do {
                cloned = try Clonefile.attempt(
                    source: source,
                    destination: destination
                )
            } catch {
                // Clonefile failed - fall through to copyfile
                cloned = false
            }

            if cloned {
                return .reflinked
            }

            // Use copyfile with COPYFILE_CLONE flag
            do {
                try Copyfile.clone(
                    source: source,
                    destination: destination
                )
                return .copied
            } catch {
                throw Error(from: error)
            }

        #elseif os(Linux)
            // Try FICLONE first
            let srcDescriptor: Kernel.Descriptor
            do {
                srcDescriptor = try Kernel.File.Open.open(
                    path: source,
                    mode: .read,
                    options: [],
                    permissions: 0
                )
            } catch let error as Kernel.File.Open.Error {
                if case .path(.notFound) = error {
                    throw Error.sourceNotFound
                }
                throw Error.notSupported
            }
            defer { try? Kernel.Close.close(srcDescriptor) }

            // Get file size for copy_file_range
            let size: Int
            do {
                size = try Metadata.size(at: source)
            } catch {
                throw Error.notSupported
            }

            // Create destination file
            let dstDescriptor: Kernel.Descriptor
            do {
                dstDescriptor = try Kernel.File.Open.open(
                    path: destination,
                    mode: .write,
                    options: [.create, .exclusive],
                    permissions: 0o644
                )
            } catch let error as Kernel.File.Open.Error {
                if case .path(.exists) = error {
                    throw Error.destinationExists
                }
                throw Error.notSupported
            }
            defer { try? Kernel.Close.close(dstDescriptor) }

            // Try FICLONE
            var reflinked = false
            do {
                reflinked = try Ficlone.attempt(
                    source: srcDescriptor,
                    destination: dstDescriptor
                )
            } catch {
                reflinked = false
            }

            if reflinked {
                return .reflinked
            }

            // Use copy_file_range
            do {
                try CopyRange.copy(
                    source: srcDescriptor,
                    destination: dstDescriptor,
                    length: size
                )
                return .copied
            } catch let error as Error.Syscall {
                try? Kernel.Unlink.unlink(destination)
                throw Error(from: error)
            } catch {
                try? Kernel.Unlink.unlink(destination)
                throw .notSupported
            }

        #elseif os(Windows)
            do {
                try Copy.file(
                    source: source,
                    destination: destination
                )
                return .copied
            } catch {
                throw Error(from: error)
            }

        #else
            throw Error.notSupported
        #endif
    }

    /// Copies a file without attempting reflink.
    private static func copyOnly(
        from source: FilePath,
        to destination: FilePath
    ) throws(Error) {
        #if os(macOS)
            do {
                try Copyfile.data(
                    source: source,
                    destination: destination
                )
            } catch {
                throw Error(from: error)
            }

        #elseif os(Linux)
            let srcDescriptor: Kernel.Descriptor
            do {
                srcDescriptor = try Kernel.File.Open.open(
                    path: source,
                    mode: .read,
                    options: [],
                    permissions: 0
                )
            } catch let error as Kernel.File.Open.Error {
                if case .path(.notFound) = error {
                    throw Error.sourceNotFound
                }
                throw Error.notSupported
            }
            defer { try? Kernel.Close.close(srcDescriptor) }

            let size: Int
            do {
                size = try Metadata.size(at: source)
            } catch {
                throw Error.notSupported
            }

            let dstDescriptor: Kernel.Descriptor
            do {
                dstDescriptor = try Kernel.File.Open.open(
                    path: destination,
                    mode: .write,
                    options: [.create, .exclusive],
                    permissions: 0o644
                )
            } catch let error as Kernel.File.Open.Error {
                if case .path(.exists) = error {
                    throw Error.destinationExists
                }
                throw Error.notSupported
            }
            defer { try? Kernel.Close.close(dstDescriptor) }

            do {
                try CopyRange.copy(
                    source: srcDescriptor,
                    destination: dstDescriptor,
                    length: size
                )
            } catch let error as Error.Syscall {
                try? Kernel.Unlink.unlink(destination)
                throw Error(from: error)
            } catch {
                try? Kernel.Unlink.unlink(destination)
                throw .notSupported
            }

        #elseif os(Windows)
            do {
                try Copy.file(
                    source: source,
                    destination: destination
                )
            } catch {
                throw Error(from: error)
            }

        #else
            throw Error.notSupported
        #endif
    }
}

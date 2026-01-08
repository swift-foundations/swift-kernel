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

// MARK: - Clone API

extension Kernel.File.Clone {
    /// Clones a file from source to destination.
    ///
    /// ## Threading
    /// This function is thread-safe. Multiple threads may call `clone()` concurrently
    /// on different source/destination pairs. Cloning the same source to different
    /// destinations concurrently is safe.
    ///
    /// ## Blocking Behavior
    /// This function performs blocking syscalls (`clonefile(2)` / `FICLONE` /
    /// `copy_file_range` / `CopyFileW`) and should not be called from Swift's
    /// cooperative thread pool. Use a dedicated executor for file operations.
    ///
    /// - Parameters:
    ///   - source: Path to the source file.
    ///   - destination: Path to the destination (must not exist).
    ///   - behavior: The cloning behavior policy.
    /// - Returns: The result indicating whether reflink or copy was used.
    /// - Throws: `Kernel.File.Clone.Error` if the operation fails.
    public static func clone(
        from source: borrowing Kernel.Path,
        to destination: borrowing Kernel.Path,
        behavior: Behavior
    ) throws(Kernel.File.Clone.Error) -> Result {
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
        from source: borrowing Kernel.Path,
        to destination: borrowing Kernel.Path
    ) throws(Kernel.File.Clone.Error) -> Result {
        #if os(macOS)
            let cloned: Bool
            do {
                cloned = try Clonefile.attempt(source: source, destination: destination)
            } catch {
                throw Error(from: error)
            }
            if cloned {
                return .reflinked
            }
            throw Error.notSupported

        #elseif os(Linux)
            // On Linux, we need to open files to use FICLONE
            let srcDescriptor = try openSource(source)
            defer { try? Kernel.Close.close(srcDescriptor) }

            let dstDescriptor = try createDestination(destination)
            defer { try? Kernel.Close.close(dstDescriptor) }

            let cloned: Bool
            do {
                cloned = try Ficlone.attempt(
                    source: srcDescriptor,
                    destination: dstDescriptor
                )
            } catch {
                try? Kernel.Unlink.unlink(destination)
                throw Error(from: error)
            }
            if cloned {
                return .reflinked
            }
            try? Kernel.Unlink.unlink(destination)
            throw Error.notSupported

        #elseif os(Windows)
            throw Error.notSupported

        #else
            throw Error.notSupported
        #endif
    }

    /// Clones using reflink if available, falls back to copy.
    private static func cloneWithFallback(
        from source: borrowing Kernel.Path,
        to destination: borrowing Kernel.Path
    ) throws(Kernel.File.Clone.Error) -> Result {
        #if os(macOS)
            // First try pure clonefile
            var cloned = false
            do {
                cloned = try Clonefile.attempt(source: source, destination: destination)
            } catch {
                cloned = false
            }

            if cloned {
                return .reflinked
            }

            // Use copyfile with COPYFILE_CLONE flag
            do {
                try Copyfile.clone(source: source, destination: destination)
                return .copied
            } catch {
                throw Error(from: error)
            }

        #elseif os(Linux)
            let srcDescriptor = try openSource(source)
            defer { try? Kernel.Close.close(srcDescriptor) }

            let size = try getSize(source)

            let dstDescriptor = try createDestination(destination)
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
            } catch {
                try? Kernel.Unlink.unlink(destination)
                throw Error(from: error)
            }

        #elseif os(Windows)
            do {
                try Copy.file(source: source, destination: destination)
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
        from source: borrowing Kernel.Path,
        to destination: borrowing Kernel.Path
    ) throws(Kernel.File.Clone.Error) {
        #if os(macOS)
            do {
                try Copyfile.data(source: source, destination: destination)
            } catch {
                throw Error(from: error)
            }

        #elseif os(Linux)
            let srcDescriptor = try openSource(source)
            defer { try? Kernel.Close.close(srcDescriptor) }

            let size = try getSize(source)

            let dstDescriptor = try createDestination(destination)
            defer { try? Kernel.Close.close(dstDescriptor) }

            do {
                try CopyRange.copy(
                    source: srcDescriptor,
                    destination: dstDescriptor,
                    length: size
                )
            } catch {
                try? Kernel.Unlink.unlink(destination)
                throw Error(from: error)
            }

        #elseif os(Windows)
            do {
                try Copy.file(source: source, destination: destination)
            } catch {
                throw Error(from: error)
            }

        #else
            throw Error.notSupported
        #endif
    }
}

// MARK: - Linux Helpers

#if os(Linux)
    extension Kernel.File.Clone {
        private static func openSource(_ path: borrowing Kernel.Path) throws(Kernel.File.Clone.Error) -> Kernel.Descriptor {
            do {
                return try Kernel.File.Open.open(
                    path: path,
                    mode: .read,
                    options: [],
                    permissions: 0
                )
            } catch {
                if case .path(.notFound) = error {
                    throw Error.sourceNotFound
                }
                throw Error.notSupported
            }
        }

        private static func createDestination(_ path: borrowing Kernel.Path) throws(Kernel.File.Clone.Error) -> Kernel.Descriptor {
            do {
                return try Kernel.File.Open.open(
                    path: path,
                    mode: .write,
                    options: [.create, .exclusive],
                    permissions: .standard
                )
            } catch {
                if case .path(.exists) = error {
                    throw Error.destinationExists
                }
                throw Error.notSupported
            }
        }

        private static func getSize(_ path: borrowing Kernel.Path) throws(Kernel.File.Clone.Error) -> Int {
            do {
                return try Metadata.size(at: path)
            } catch {
                throw Error.notSupported
            }
        }
    }
#endif

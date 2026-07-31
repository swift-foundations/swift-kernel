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

public import Path_Primitives

// Platform mechanisms are referenced by their qualified L2 homes after the
// re-anchoring (swift-standards/swift-darwin-standard#3,
// swift-standards/swift-linux-standard#3): the modules below are already in
// the transitive closure through `Kernel Core`'s re-exports, so the per-file
// import follows the realized precedent in `Kernel.Event.Source+Kqueue.swift`
// and needs no new package dependency.
#if os(macOS)
    internal import Darwin_Kernel_Standard
#elseif os(Linux)
    internal import Linux_Kernel_File_Standard
#endif

#if os(Windows)
    // Direct import for per-file member visibility of `Copy.file` and
    // `Clone.Error.init(from:)` (declared in the L2 modules this re-exports).
    // Note: this does NOT enable bare sibling references like `Copy` — on the
    // Windows 6.3.3 toolchain, unqualified enclosing-context lookup two hops
    // up (`Clone` → `File` → cross-module member `Copy`) fails regardless of
    // imports; sibling references must be qualified as `Kernel.File.Copy`.
    public import Windows_Kernel_File
#endif

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
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed,
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
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Clone.Error) -> Result {
        #if os(macOS)
            let cloned: Bool
            do throws(Darwin.Kernel.File.Clone.Error.Syscall) {
                cloned = try Darwin.Kernel.File.Clone.Clonefile.attempt(
                    source: source,
                    destination: destination
                )
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
            let dstDescriptor = try createDestination(destination)

            let cloned: Bool
            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                cloned = try Linux.Kernel.File.Clone.Ficlone.attempt(
                    source: srcDescriptor,
                    destination: dstDescriptor
                )
            } catch {
                // Best-effort cleanup: the clone attempt failed, so the
                // destination is unlinked before surfacing the original error.
                // A failure to unlink here does not change the outcome.
                do throws(Kernel.File.Delete.Error) {
                    try Kernel.File.Delete.delete(destination)
                } catch {
                }
                throw Error(from: error)
            }
            if cloned {
                return .reflinked
            }
            // Best-effort cleanup: reflink is unsupported, so the destination
            // created by `createDestination` is unlinked before surfacing
            // `.notSupported`. A failure to unlink here does not change the outcome.
            do throws(Kernel.File.Delete.Error) {
                try Kernel.File.Delete.delete(destination)
            } catch {
            }
            throw Error.notSupported

        #elseif os(Windows)
            throw Error.notSupported

        #else
            throw Error.notSupported
        #endif
    }

    /// Clones using reflink if available, falls back to copy.
    private static func cloneWithFallback(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Clone.Error) -> Result {
        #if os(macOS)
            // First try pure clonefile
            var cloned = false
            do throws(Darwin.Kernel.File.Clone.Error.Syscall) {
                cloned = try Darwin.Kernel.File.Clone.Clonefile.attempt(
                    source: source,
                    destination: destination
                )
            } catch {
                cloned = false
            }

            if cloned {
                return .reflinked
            }

            // Use copyfile with COPYFILE_CLONE flag
            do throws(Darwin.Kernel.File.Clone.Error.Syscall) {
                try Darwin.Kernel.File.Clone.Copyfile.clone(
                    source: source,
                    destination: destination
                )
                return .copied
            } catch {
                throw Error(from: error)
            }

        #elseif os(Linux)
            let srcDescriptor = try openSource(source)
            let size = try getSize(source)

            let dstDescriptor = try createDestination(destination)

            // Try FICLONE
            var reflinked = false
            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                reflinked = try Linux.Kernel.File.Clone.Ficlone.attempt(
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
            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                try Linux.Kernel.File.Clone.CopyRange.copy(
                    source: srcDescriptor,
                    destination: dstDescriptor,
                    length: size
                )
                return .copied
            } catch {
                // Best-effort cleanup: copy_file_range failed, so the destination
                // created by `createDestination` is unlinked before surfacing the
                // original error. A failure to unlink here does not change the outcome.
                do throws(Kernel.File.Delete.Error) {
                    try Kernel.File.Delete.delete(destination)
                } catch {
                }
                throw Error(from: error)
            }

        #elseif os(Windows)
            do throws(Windows.`32`.Kernel.File.Clone.Error.Syscall) {
                try Kernel.File.Copy.file(source: source, destination: destination)
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
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Clone.Error) {
        #if os(macOS)
            do throws(Darwin.Kernel.File.Clone.Error.Syscall) {
                try Darwin.Kernel.File.Clone.Copyfile.data(
                    source: source,
                    destination: destination
                )
            } catch {
                throw Error(from: error)
            }

        #elseif os(Linux)
            let srcDescriptor = try openSource(source)
            let size = try getSize(source)

            let dstDescriptor = try createDestination(destination)

            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                try Linux.Kernel.File.Clone.CopyRange.copy(
                    source: srcDescriptor,
                    destination: dstDescriptor,
                    length: size
                )
            } catch {
                // Best-effort cleanup: copy_file_range failed, so the destination
                // created by `createDestination` is unlinked before surfacing the
                // original error. A failure to unlink here does not change the outcome.
                do throws(Kernel.File.Delete.Error) {
                    try Kernel.File.Delete.delete(destination)
                } catch {
                }
                throw Error(from: error)
            }

        #elseif os(Windows)
            do throws(Windows.`32`.Kernel.File.Clone.Error.Syscall) {
                try Kernel.File.Copy.file(source: source, destination: destination)
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
        private static func openSource(_ path: borrowing Path.Borrowed) throws(Kernel.File.Clone.Error) -> Kernel.Descriptor {
            do throws(Kernel.File.Open.Error) {
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

        private static func createDestination(_ path: borrowing Path.Borrowed) throws(Kernel.File.Clone.Error) -> Kernel.Descriptor {
            do throws(Kernel.File.Open.Error) {
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

        private static func getSize(_ path: borrowing Path.Borrowed) throws(Kernel.File.Clone.Error) -> Int {
            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                return try Linux.Kernel.File.Clone.Metadata.size(at: path)
            } catch {
                throw Error.notSupported
            }
        }
    }
#endif

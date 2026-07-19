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

public import Error_Primitives
public import Path_Primitives

// MARK: - Copy API

extension Kernel.File.Copy {
    /// Copies a file from source to destination.
    ///
    /// ## Threading
    /// This function is thread-safe. Multiple threads may call `copy()` concurrently
    /// on different source/destination pairs.
    ///
    /// ## Blocking Behavior
    /// This function performs blocking syscalls and should not be called from Swift's
    /// cooperative thread pool. Use a dedicated executor for file operations.
    ///
    /// - Parameters:
    ///   - source: Path to the source file.
    ///   - destination: Path to the destination.
    ///   - options: Copy options (overwrite, attributes, symlinks).
    /// - Throws: `Kernel.File.Copy.Error` if the operation fails.
    public static func copy(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed,
        options: Options = .init()
    ) throws(Kernel.File.Copy.Error) {
        // Get source stats (use lstat when not following symlinks)
        let sourceStats = try getSourceStats(source, followSymlinks: options.followSymlinks)

        // Check if source is a directory
        if sourceStats.type == .directory {
            throw .isDirectory
        }

        // Check if source is a symlink and we're not following
        let sourceIsSymlink: Bool
        if case .link(.symbolic) = sourceStats.type {
            sourceIsSymlink = true
        } else {
            sourceIsSymlink = false
        }

        // Check destination and handle overwrite
        try handleDestination(destination, overwrite: options.overwrite)

        // Handle symlink copying when followSymlinks=false
        if !options.followSymlinks && sourceIsSymlink {
            try copySymlink(from: source, to: destination)
            return
        }

        // Use Kernel.File.Clone for data copy
        try cloneFile(from: source, to: destination)

        // Apply attributes if requested
        if options.copyAttributes {
            try copyAttributes(
                to: destination,
                permissions: sourceStats.permissions,
                accessTime: sourceStats.accessTime,
                modificationTime: sourceStats.modificationTime
            )
        }
    }
}

// MARK: - Source Stats

extension Kernel.File.Copy {
    private static func getSourceStats(
        _ source: borrowing Path.Borrowed,
        followSymlinks: Bool
    ) throws(Kernel.File.Copy.Error) -> Kernel.File.Stats {
        do throws(Kernel.File.Stats.Error) {
            if followSymlinks {
                return try Kernel.File.Stats.get(path: source)
            } else {
                return try Kernel.File.Stats.lget(path: source)
            }
        } catch let error {
            // Check if it's a "not found" error (platform code namespaces:
            // the POSIX constants live in ISO_9945, the Win32 ones in
            // swift-windows-standard)
            #if os(Windows)
                if case .platform(let platformError) = error,
                    platformError.code == .Windows.ERROR_FILE_NOT_FOUND
                        || platformError.code == .Windows.ERROR_PATH_NOT_FOUND
                {
                    throw .sourceNotFound
                }
            #else
                if case .platform(let platformError) = error,
                    platformError.code == .POSIX.ENOENT
                {
                    throw .sourceNotFound
                }
            #endif
            // .stats wrapper case removed in Cycle 18e+18f per L1-domain-only;
            // route through .platform with a synthetic POSIX code reflecting
            // the stat failure category for downstream dispatch.
            throw .operation("stat failed: \(error)")
        }
    }
}

// MARK: - Destination Handling

extension Kernel.File.Copy {
    private static func handleDestination(
        _ destination: borrowing Path.Borrowed,
        overwrite: Bool
    ) throws(Kernel.File.Copy.Error) {
        // Check if destination exists
        let destStats: Kernel.File.Stats?
        do throws(Kernel.File.Stats.Error) {
            destStats = try Kernel.File.Stats.lget(path: destination)
        } catch {
            // Destination doesn't exist - that's fine
            destStats = nil
        }

        guard let stats = destStats else {
            return  // No destination, nothing to do
        }

        if !overwrite {
            throw .destinationExists
        }

        // Cannot overwrite a directory
        if stats.type == .directory {
            throw .isDirectory
        }

        // Unlink destination before copy
        do throws(Kernel.File.Delete.Error) {
            try Kernel.File.Delete.delete(destination)
        } catch let error {
            throw .unlink(error)
        }
    }
}

// MARK: - Clone File

extension Kernel.File.Copy {
    private static func cloneFile(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Copy.Error) {
        do throws(Kernel.File.Clone.Error) {
            _ = try Kernel.File.Clone.clone(
                from: source,
                to: destination,
                behavior: .reflinkOrCopy
            )
        } catch let error {
            switch error {
            case .sourceNotFound:
                throw .sourceNotFound
            case .destinationExists:
                throw .destinationExists
            case .permissionDenied:
                throw .permissionDenied
            case .isDirectory:
                throw .isDirectory
            default:
                throw .clone(error)
            }
        }
    }
}

// MARK: - Symlink Copy

extension Kernel.File.Copy {
    private static func copySymlink(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Copy.Error) {
        // Read the symlink target
        let target: Swift.String
        do throws(Kernel.Link.Symbolic.Error) {
            let kernelTarget = try Kernel.Link.Symbolic.readTarget(at: source)
            target = Swift.String(kernelTarget)
        } catch let error {
            // .symlink wrapper case removed in Cycle 18c per L1-domain-only;
            // route through .operation with a descriptive message.
            throw .operation("readlink failed: \(error)")
        }

        // Create symlink at destination using scoped path conversion.
        //
        // F-007: this used to be `try? Path.scope(target) { ... }` with an
        // inner `do { ... } catch let error as X { } catch {}` — both the
        // outer `try?` (silently discarding a Path.scope validation
        // failure, e.g. a symlink target containing a NUL byte) and the
        // inner empty `catch {}` swallowed real failures, letting copySymlink
        // — and therefore Copy.copy — return success without ever creating
        // the destination symlink. Propagate both failure modes as typed
        // Copy.Error instead: no try?, no empty catch.
        do {
            try Path.scope(target) { targetView in
                try Kernel.Link.Symbolic.create(target: targetView, at: destination)
            }
        } catch {
            throw .operation("symlink create failed: \(error)")
        }
    }
}

// MARK: - Attribute Copy

extension Kernel.File.Copy {
    private static func copyAttributes(
        to destination: borrowing Path.Borrowed,
        permissions: Kernel.File.Permissions,
        accessTime: Kernel.Time,
        modificationTime: Kernel.Time
    ) throws(Kernel.File.Copy.Error) {
        // Set permissions
        do throws(Kernel.File.Attributes.Error) {
            try Kernel.File.Attributes.set(permissions, at: destination)
        } catch {
            throw .attributes(error)
        }

        // Set timestamps
        do throws(Kernel.File.Times.Error) {
            try Kernel.File.Times.set(
                access: accessTime,
                modification: modificationTime,
                at: destination
            )
        } catch {
            throw .times(error)
        }
    }
}

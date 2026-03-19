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
        from source: borrowing Kernel.Path.View,
        to destination: borrowing Kernel.Path.View,
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
        _ source: borrowing Kernel.Path.View,
        followSymlinks: Bool
    ) throws(Kernel.File.Copy.Error) -> Kernel.File.Stats {
        do {
            if followSymlinks {
                return try Kernel.File.Stats.get(path: source)
            } else {
                return try Kernel.File.Stats.lget(path: source)
            }
        } catch let error {
            // Check if it's a "not found" error
            if case .platform(let platformError) = error,
               platformError.code == .POSIX.ENOENT {
                throw .sourceNotFound
            }
            throw .stats(error)
        }
    }
}

// MARK: - Destination Handling

extension Kernel.File.Copy {
    private static func handleDestination(
        _ destination: borrowing Kernel.Path.View,
        overwrite: Bool
    ) throws(Kernel.File.Copy.Error) {
        // Check if destination exists
        let destStats: Kernel.File.Stats?
        do {
            destStats = try Kernel.File.Stats.lget(path: destination)
        } catch {
            // Destination doesn't exist - that's fine
            destStats = nil
        }

        guard let stats = destStats else {
            return // No destination, nothing to do
        }

        if !overwrite {
            throw .destinationExists
        }

        // Cannot overwrite a directory
        if stats.type == .directory {
            throw .isDirectory
        }

        // Unlink destination before copy
        do {
            try Kernel.File.Delete.delete(destination)
        } catch let error {
            throw .unlink(error)
        }
    }
}

// MARK: - Clone File

extension Kernel.File.Copy {
    private static func cloneFile(
        from source: borrowing Kernel.Path.View,
        to destination: borrowing Kernel.Path.View
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
        from source: borrowing Kernel.Path.View,
        to destination: borrowing Kernel.Path.View
    ) throws(Kernel.File.Copy.Error) {
        // Read the symlink target
        let target: Swift.String
        do throws(Kernel.Link.Symbolic.Error) {
            let kernelTarget = try Kernel.Link.Symbolic.readTarget(at: source)
            target = Swift.String(kernelTarget)
        } catch let error {
            throw .symlink(error)
        }

        // Create symlink at destination using scoped path conversion
        var createError: Kernel.Link.Symbolic.Error?
        try? Kernel.Path.scope(target) { targetView in
            do {
                try Kernel.Link.Symbolic.create(target: targetView, at: destination)
            } catch let error as Kernel.Link.Symbolic.Error {
                createError = error
            } catch {}
        }
        if let error = createError {
            throw .symlink(error)
        }
    }
}

// MARK: - Attribute Copy

extension Kernel.File.Copy {
    private static func copyAttributes(
        to destination: borrowing Kernel.Path.View,
        permissions: Kernel.File.Permissions,
        accessTime: Kernel.Time,
        modificationTime: Kernel.Time
    ) throws(Kernel.File.Copy.Error) {
        // Set permissions
        do {
            try Kernel.File.Attributes.setPermissions(path: destination, permissions: permissions)
        } catch let error {
            throw .attributes(error)
        }

        // Set timestamps
        do {
            try Kernel.File.Times.setTimes(
                path: destination,
                accessTime: accessTime,
                modificationTime: modificationTime
            )
        } catch let error {
            throw .times(error)
        }
    }
}

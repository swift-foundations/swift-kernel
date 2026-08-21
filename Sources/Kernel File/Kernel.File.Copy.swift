internal import Error_Primitives
public import Path_Primitives

extension Kernel.File.Copy {

    public static func copy(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed,
        options: Options = .init()
    ) throws(Kernel.File.Copy.Error) {

        let sourceStats = try getSourceStats(source, followSymlinks: options.followSymlinks)

        if sourceStats.type == .directory {
            throw .isDirectory
        }

        let sourceIsSymlink: Bool
        if case .link(.symbolic) = sourceStats.type {
            sourceIsSymlink = true
        } else {
            sourceIsSymlink = false
        }

        try handleDestination(destination, overwrite: options.overwrite)

        if !options.followSymlinks && sourceIsSymlink {
            try copySymlink(from: source, to: destination)
            return
        }

        try cloneFile(from: source, to: destination)

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

            throw .operation("stat failed: \(error)")
        }
    }
}

extension Kernel.File.Copy {
    private static func handleDestination(
        _ destination: borrowing Path.Borrowed,
        overwrite: Bool
    ) throws(Kernel.File.Copy.Error) {

        let destStats: Kernel.File.Stats?
        do throws(Kernel.File.Stats.Error) {
            destStats = try Kernel.File.Stats.lget(path: destination)
        } catch {

            destStats = nil
        }

        guard let stats = destStats else {
            return
        }

        if !overwrite {
            throw .destinationExists
        }

        if stats.type == .directory {
            throw .isDirectory
        }

        do throws(Kernel.File.Delete.Error) {
            try Kernel.File.Delete.delete(destination)
        } catch let error {
            throw .unlink(error)
        }
    }
}

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

                throw .operation("clone failed: \(error)")
            }
        }
    }
}

extension Kernel.File.Copy {
    private static func copySymlink(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Copy.Error) {

        let target: Swift.String
        do throws(Kernel.Link.Symbolic.Error) {
            let kernelTarget = try Kernel.Link.Symbolic.readTarget(at: source)
            target = Swift.String(kernelTarget)
        } catch let error {

            throw .operation("readlink failed: \(error)")
        }

        do {
            try Path.scope(target) { targetView in
                try Kernel.Link.Symbolic.create(target: targetView, at: destination)
            }
        } catch {
            throw .operation("symlink create failed: \(error)")
        }
    }
}

extension Kernel.File.Copy {
    private static func copyAttributes(
        to destination: borrowing Path.Borrowed,
        permissions: Kernel.File.Permissions,
        accessTime: Kernel.Time,
        modificationTime: Kernel.Time
    ) throws(Kernel.File.Copy.Error) {

        do throws(Kernel.File.Attributes.Error) {
            try Kernel.File.Attributes.set(permissions, at: destination)
        } catch {
            throw .attributes(error)
        }

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

public import Path_Primitives

#if os(macOS)
    internal import Darwin_Kernel_Standard
#elseif os(Linux)
    internal import Linux_Kernel_File_Standard
#endif

#if os(Windows)

    public import Windows_Kernel_File
#endif

extension Kernel.File.Clone {

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

extension Kernel.File.Clone {

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

            let srcDescriptor = try openSource(source)
            let dstDescriptor = try createDestination(destination)

            let cloned: Bool
            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                cloned = try Linux.Kernel.File.Clone.Ficlone.attempt(
                    source: srcDescriptor,
                    destination: dstDescriptor
                )
            } catch {

                do throws(Kernel.File.Delete.Error) {
                    try Kernel.File.Delete.delete(destination)
                } catch {
                }
                throw Error(from: error)
            }
            if cloned {
                return .reflinked
            }

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

    private static func cloneWithFallback(
        from source: borrowing Path.Borrowed,
        to destination: borrowing Path.Borrowed
    ) throws(Kernel.File.Clone.Error) -> Result {
        #if os(macOS)

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

            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                try Linux.Kernel.File.Clone.CopyRange.copy(
                    source: srcDescriptor,
                    destination: dstDescriptor,
                    length: size
                )
                return .copied
            } catch {

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

#if os(Linux)
    extension Kernel.File.Clone {
        private static func openSource(
            _ path: borrowing Path.Borrowed
        ) throws(Kernel.File.Clone.Error) -> Kernel.Descriptor {
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

        private static func createDestination(
            _ path: borrowing Path.Borrowed
        ) throws(Kernel.File.Clone.Error) -> Kernel.Descriptor {
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

        private static func getSize(
            _ path: borrowing Path.Borrowed
        ) throws(Kernel.File.Clone.Error) -> Int {
            do throws(Linux.Kernel.File.Clone.Error.Syscall) {
                return try Linux.Kernel.File.Clone.Metadata.size(at: path)
            } catch {
                throw Error.notSupported
            }
        }
    }
#endif

#if os(Windows)

    internal import Windows_Kernel_File

    extension Kernel.File.Clone.Error {

        internal init(from syscall: Windows.`32`.Kernel.File.Clone.Error.Syscall) {
            self.init(Windows.`32`.Kernel.File.Clone.Error(from: syscall))
        }

        internal init(_ error: Windows.`32`.Kernel.File.Clone.Error) {
            switch error {
            case .notSupported:
                self = .notSupported

            case .crossDevice:
                self = .crossDevice

            case .sourceNotFound:
                self = .sourceNotFound

            case .destinationExists:
                self = .destinationExists

            case .permissionDenied:
                self = .permissionDenied

            case .isDirectory:
                self = .isDirectory

            case .platform(let code, let operation):
                self = .platform(code: code, operation: .init(operation))
            }
        }
    }

    extension Kernel.File.Clone.Error.Operation {

        internal init(_ operation: Windows.`32`.Kernel.File.Clone.Error.Operation) {
            switch operation {
            case .clonefile:
                self = .clonefile

            case .copyfile:
                self = .copyfile

            case .ficlone:
                self = .ficlone

            case .copyFileRange:
                self = .copyFileRange

            case .duplicateExtents:
                self = .duplicateExtents

            case .statfs:
                self = .statfs

            case .stat:
                self = .stat

            case .copy:
                self = .copy
            }
        }
    }

#endif

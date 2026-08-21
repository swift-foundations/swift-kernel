#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

    internal import Darwin_Kernel_Standard

    extension Kernel.File.Clone.Error {

        internal init(from syscall: Darwin.Kernel.File.Clone.Error.Syscall) {
            switch syscall {
            case .notSupported:
                self = .notSupported

            case .platform(let code, let operation):
                self.init(code: code, operation: .init(operation))
            }
        }
    }

    extension Kernel.File.Clone.Error.Operation {

        internal init(_ operation: Darwin.Kernel.File.Clone.Error.Operation) {
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

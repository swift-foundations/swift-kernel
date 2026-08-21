#if os(Linux)

    internal import Linux_Kernel_File_Standard

    extension Kernel.File.Clone.Error {

        internal init(from syscall: Linux.Kernel.File.Clone.Error.Syscall) {
            switch syscall {
            case .platform(let code, let operation):
                self.init(code: code, operation: .init(operation))
            }
        }
    }

    extension Kernel.File.Clone.Error.Operation {

        internal init(_ operation: Linux.Kernel.File.Clone.Error.Operation) {
            switch operation {
            case .statfs:
                self = .statfs

            case .stat:
                self = .stat

            case .ficlone:
                self = .ficlone

            case .copyFileRange:
                self = .copyFileRange
            }
        }
    }

#endif

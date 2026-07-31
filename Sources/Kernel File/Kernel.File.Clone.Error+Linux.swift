// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Linux platform binding for the hoisted `Kernel.File.Clone.Error`
// vocabulary. `Linux.Kernel.File.Clone.Error.Syscall` carries only the
// `.platform` case and a four-member `Operation` set (the Linux mechanisms
// are `statfs(2)`, `stat(2)`, `ioctl(FICLONE)` and `copy_file_range(2)`), so
// the bridge widens into kernel's eight-member set.

#if os(Linux)

    internal import Linux_Kernel_File_Standard

    extension Kernel.File.Clone.Error {
        /// Creates a semantic kernel error from a Linux clone syscall failure.
        internal init(from syscall: Linux.Kernel.File.Clone.Error.Syscall) {
            switch syscall {
            case .platform(let code, let operation):
                self.init(code: code, operation: .init(operation))
            }
        }
    }

    extension Kernel.File.Clone.Error.Operation {
        /// Transliterates a Linux clone operation into kernel vocabulary.
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

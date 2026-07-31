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

// Windows platform binding for the hoisted `Kernel.File.Clone.Error`
// vocabulary. Win32 codes are not POSIX codes, so kernel's own
// `init(code:operation:)` cannot classify them; the semantic mapping stays
// with its owner (`Windows.\`32\`.Kernel.File.Clone.Error.init(from:)`,
// swift-windows-32) and kernel only transliterates the resulting semantic
// case — the shapes mirror each other one-for-one per [PLAT-ARCH-008c].

#if os(Windows)

    internal import Windows_Kernel_File

    extension Kernel.File.Clone.Error {
        /// Creates a semantic kernel error from a Windows clone syscall failure.
        internal init(from syscall: Windows.`32`.Kernel.File.Clone.Error.Syscall) {
            self.init(Windows.`32`.Kernel.File.Clone.Error(from: syscall))
        }

        /// Transliterates a Windows semantic clone error into kernel vocabulary.
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
        /// Transliterates a Windows clone operation into kernel vocabulary.
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

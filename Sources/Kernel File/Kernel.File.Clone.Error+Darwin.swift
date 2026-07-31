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

// Darwin platform binding for the hoisted `Kernel.File.Clone.Error`
// vocabulary. After the re-anchoring (swift-standards/swift-darwin-standard#3)
// the Darwin clone mechanisms throw their own nominally distinct
// `Darwin.Kernel.File.Clone.Error.Syscall`; the case and `Operation` sets
// still match kernel's one-for-one, so the bridge below is a structural
// transliteration onto kernel's existing POSIX code mapping.

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

    internal import Darwin_Kernel_Standard

    extension Kernel.File.Clone.Error {
        /// Creates a semantic kernel error from a Darwin clone syscall failure.
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
        /// Transliterates a Darwin clone operation into kernel vocabulary.
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

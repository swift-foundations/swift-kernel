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

public import Error_Primitives

// MARK: - POSIX Error Conversion

extension Kernel.File.Clone.Error {
    /// Creates a semantic error from a raw syscall error.
    public init(from syscall: Syscall) {
        switch syscall {
        case .notSupported:
            self = .notSupported

        case .platform(let code, let operation):
            self.init(code: code, operation: operation)
        }
    }

    /// Maps a platform error code to a semantic error.
    ///
    /// On POSIX legs the errno is classified here. On Windows the code is
    /// carried through unclassified: Win32 codes are not POSIX codes, and
    /// `Error.Code.POSIX` is not even reachable on that leg — its owner,
    /// ISO 9945 Core, is not in the Windows build graph. Windows failures
    /// reach kernel already classified by their owner and are transliterated
    /// in `Kernel.File.Clone.Error+Windows.swift`, so classifying again here
    /// would grow a second, competing Windows mapping.
    ///
    /// - Note: This is SPI for platform-specific packages.
    @_spi(Syscall)
    public init(code: Error_Primitives.Error.Code, operation: Operation) {
        #if os(Windows)
            self = .platform(code: code, operation: operation)
        #else
            switch code {
            case _ where code == .POSIX.ENOENT:
                self = .sourceNotFound

            case _ where code == .POSIX.EEXIST:
                self = .destinationExists

            case _ where code == .POSIX.EACCES,
                _ where code == .POSIX.EPERM:
                self = .permissionDenied

            case _ where code == .POSIX.EXDEV:
                self = .crossDevice

            case _ where code == .POSIX.EISDIR:
                self = .isDirectory

            case _ where Error_Primitives.Error.Code.POSIX.isENOTSUP(code):
                self = .notSupported

            default:
                self = .platform(code: code, operation: operation)
            }
        #endif
    }
}

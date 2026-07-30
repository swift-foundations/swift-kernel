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

    /// Maps a POSIX error code to a semantic error.
    ///
    /// - Note: This is SPI for platform-specific packages.
    @_spi(Syscall)
    public init(code: Error_Primitives.Error.Code, operation: Operation) {
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
    }
}

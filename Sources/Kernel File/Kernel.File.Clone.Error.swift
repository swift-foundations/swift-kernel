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

extension Kernel.File.Clone {
    /// Errors that can occur during clone operations.
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        /// Reflink is not supported on this filesystem.
        ///
        /// Returned by `.reflinkOrFail` when the filesystem doesn't support CoW.
        case notSupported

        /// Source and destination are on different filesystems/volumes.
        ///
        /// Reflink requires both paths to be on the same volume.
        case crossDevice

        /// The source file does not exist.
        case sourceNotFound

        /// The destination already exists.
        ///
        /// Clone operations do not overwrite by default.
        case destinationExists

        /// Permission denied for source or destination.
        case permissionDenied

        /// The source is a directory, not a regular file.
        ///
        /// Use a recursive directory clone for directories.
        case isDirectory

        /// A platform-specific error occurred.
        case platform(code: Error_Primitives.Error.Code, operation: Operation)
    }
}

extension Kernel.File.Clone.Error {
    public var description: Swift.String {
        switch self {
        case .notSupported:
            return "Reflink not supported on this filesystem"

        case .crossDevice:
            return "Source and destination are on different devices"

        case .sourceNotFound:
            return "Source file not found"

        case .destinationExists:
            return "Destination already exists"

        case .permissionDenied:
            return "Permission denied"

        case .isDirectory:
            return "Source is a directory"

        case .platform(let code, let operation):
            return "Platform error \(code) during \(operation)"
        }
    }
}

// MARK: - Platform Bindings
//
// Per [PLAT-ARCH-008c], the platform-specific `init(from syscall:)` and
// `init(code:operation:)` mapping lives beside this type at L3:
// - POSIX: `swift-kernel` (`Kernel.File.Clone.Error+code.swift`)
// - Windows: `swift-windows-standard` (`Windows.Kernel.File.Clone.Error+code.swift`)

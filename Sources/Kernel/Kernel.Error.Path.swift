// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel.Error {
    /// Path-related error conditions.
    public enum Path: Sendable, Equatable {
        /// The specified path or file does not exist.
        /// - POSIX: `ENOENT`
        /// - Windows: `ERROR_FILE_NOT_FOUND`, `ERROR_PATH_NOT_FOUND`
        case notFound

        /// A file or directory already exists at the specified path.
        /// - POSIX: `EEXIST`
        /// - Windows: `ERROR_FILE_EXISTS`, `ERROR_ALREADY_EXISTS`
        case exists

        /// The path refers to a directory when a file was expected.
        /// - POSIX: `EISDIR`
        /// - Windows: `ERROR_DIRECTORY`
        case isDirectory

        /// The path refers to a file when a directory was expected.
        /// - POSIX: `ENOTDIR`
        /// - Windows: `ERROR_DIRECTORY_NOT_SUPPORTED`
        case notDirectory

        /// The directory is not empty and cannot be removed.
        /// - POSIX: `ENOTEMPTY`
        /// - Windows: `ERROR_DIR_NOT_EMPTY`
        case notEmpty

        /// Cross-device link attempted (e.g., rename across filesystems).
        /// - POSIX: `EXDEV`
        /// - Windows: `ERROR_NOT_SAME_DEVICE`
        case crossDevice
    }
}

extension Kernel.Error.Path: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound: return "not found"
        case .exists: return "already exists"
        case .isDirectory: return "is a directory"
        case .notDirectory: return "not a directory"
        case .notEmpty: return "directory not empty"
        case .crossDevice: return "cross-device link"
        }
    }
}

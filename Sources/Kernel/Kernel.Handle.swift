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

extension Kernel {
    /// Handle domain - file descriptor/handle validity.
    ///
    /// These errors indicate problems with file descriptors (POSIX)
    /// or HANDLEs (Windows).
    ///
    /// ## Note
    /// Named `Handle` to avoid conflict with `Kernel.Descriptor` typealias.
    public enum Handle: Sendable {
        
    }
}

extension Kernel.Handle {
    /// Handle-related errors.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// The file descriptor or handle is invalid.
        /// - POSIX: `EBADF`
        /// - Windows: `ERROR_INVALID_HANDLE`
        case invalid

        /// Too many open files.
        case limit(Limit)

        /// Limit scope for file descriptor exhaustion.
        public enum Limit: Sendable, Equatable, Hashable {
            /// Per-process file descriptor limit reached.
            /// - POSIX: `EMFILE`
            /// - Windows: `ERROR_TOO_MANY_OPEN_FILES`
            case process

            /// System-wide file descriptor limit reached.
            /// - POSIX: `ENFILE`
            case system
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Handle.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid:
            return "invalid descriptor"
        case .limit(let limit):
            return limit.description
        }
    }
}

extension Kernel.Handle.Error.Limit: CustomStringConvertible {
    public var description: String {
        switch self {
        case .process:
            return "too many open files in process"
        case .system:
            return "too many open files in system"
        }
    }
}

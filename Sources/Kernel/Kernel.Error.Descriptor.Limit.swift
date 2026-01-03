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

extension Kernel.Error.Descriptor {
    /// Limit scope for file descriptor exhaustion.
    public enum Limit: Sendable, Equatable {
        /// Per-process file descriptor limit reached.
        /// - POSIX: `EMFILE`
        /// - Windows: `ERROR_TOO_MANY_OPEN_FILES`
        case process

        /// System-wide file descriptor limit reached.
        /// - POSIX: `ENFILE`
        case system
    }
}

extension Kernel.Error.Descriptor.Limit: CustomStringConvertible {
    public var description: String {
        switch self {
        case .process: return "too many open files in process"
        case .system: return "too many open files in system"
        }
    }
}

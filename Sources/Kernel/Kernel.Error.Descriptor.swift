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
    /// File descriptor error conditions.
    public enum Descriptor: Sendable, Equatable {
        /// The file descriptor or handle is invalid.
        /// - POSIX: `EBADF`
        /// - Windows: `ERROR_INVALID_HANDLE`
        case invalid

        /// Too many open files.
        case limit(Limit)
    }
}

extension Kernel.Error.Descriptor: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "invalid descriptor"
        case .limit(let limit): return limit.description
        }
    }
}

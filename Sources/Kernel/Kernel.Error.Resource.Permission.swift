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

extension Kernel.Error.Resource {
    /// Permission error types.
    public enum Permission: Sendable, Equatable {
        /// File or directory permission denied.
        /// - POSIX: `EACCES`
        /// - Windows: `ERROR_ACCESS_DENIED`
        case denied

        /// Operation not permitted (requires privilege).
        /// - POSIX: `EPERM`
        case notPermitted
    }
}

extension Kernel.Error.Resource.Permission: CustomStringConvertible {
    public var description: String {
        switch self {
        case .denied: return "permission denied"
        case .notPermitted: return "operation not permitted"
        }
    }
}

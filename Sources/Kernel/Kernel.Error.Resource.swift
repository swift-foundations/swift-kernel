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
    /// System resource error conditions.
    public enum Resource: Sendable, Equatable {
        /// Permission-related errors.
        case permission(Permission)

        /// No space left on the device.
        /// - POSIX: `ENOSPC`
        /// - Windows: `ERROR_DISK_FULL`
        case space

        /// The operation was interrupted by a signal.
        /// - POSIX: `EINTR`
        ///
        /// - Note: Kernel does NOT retry on EINTR. Higher layers decide retry policy.
        case interrupted

        /// The operation would block on a non-blocking descriptor.
        /// - POSIX: `EAGAIN`, `EWOULDBLOCK`
        case blocked

        /// The operation is not supported on this descriptor or filesystem.
        /// - POSIX: `ENOTSUP`, `EOPNOTSUPP`
        case unsupported
    }
}

extension Kernel.Error.Resource: CustomStringConvertible {
    public var description: String {
        switch self {
        case .permission(let permission): return permission.description
        case .space: return "no space left on device"
        case .interrupted: return "interrupted"
        case .blocked: return "would block"
        case .unsupported: return "operation not supported"
        }
    }
}

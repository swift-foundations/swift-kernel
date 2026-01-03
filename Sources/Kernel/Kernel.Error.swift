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
    /// Unified error type for all kernel syscalls.
    ///
    /// Aggregates domain-specific leaf errors into a single type for use in
    /// generic syscall contexts. Each case wraps the authoritative domain error.
    ///
    /// ## Design Principles
    /// - **Semantic, not platform-specific**: Cases represent user-actionable conditions.
    /// - **Typed throws**: No `rethrows`, no `any Error`.
    /// - **Domain leaf errors**: Each case wraps the domain's own error type.
    /// - **EOF is NOT an error**: `read`/`pread` return 0 on EOF.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Path resolution errors.
        case path(Kernel.Path.Resolution.Error)

        /// File descriptor/handle errors.
        case handle(Kernel.Handle.Error)

        /// I/O operation errors.
        /// Note: EOF is NOT an error. read/pread return 0 on EOF.
        case io(Kernel.IO.Error)

        /// File locking errors.
        case lock(Kernel.Lock.Error)

        /// Memory-related errors.
        case memory(Kernel.Memory.Error)

        /// Permission errors.
        case permission(Kernel.Permission.Error)

        /// Storage space errors.
        case space(Kernel.Space.Error)

        /// Signal interruption errors.
        case signal(Kernel.Signal.Error)

        /// Non-blocking operation errors.
        case blocking(Kernel.Blocking.Error)

        /// Unmapped platform-specific errors.
        case platform(Kernel.Platform.Error)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let error):
            return "path: \(error)"
        case .handle(let error):
            return "handle: \(error)"
        case .io(let error):
            return "io: \(error)"
        case .lock(let error):
            return "lock: \(error)"
        case .memory(let error):
            return "memory: \(error)"
        case .permission(let error):
            return "permission: \(error)"
        case .space(let error):
            return "space: \(error)"
        case .signal(let error):
            return "signal: \(error)"
        case .blocking(let error):
            return "blocking: \(error)"
        case .platform(let error):
            return "\(error)"
        }
    }
}

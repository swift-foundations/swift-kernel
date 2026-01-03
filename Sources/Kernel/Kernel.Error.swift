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
    /// Maps platform errno (POSIX) and DWORD error codes (Windows) to semantic cases.
    /// Used by all Kernel syscall operations.
    ///
    /// ## Design Principles
    /// - **Semantic, not platform-specific**: Cases represent user-actionable conditions.
    /// - **Typed throws**: No `rethrows`, no `any Error`.
    /// - **Escape hatch**: `.platform(code:)` for unmapped platform errors.
    /// - **EOF is NOT an error**: `read`/`pread` return 0 on EOF.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Path-related errors.
        case path(Path)

        /// File descriptor errors.
        case descriptor(Descriptor)

        /// I/O operation errors.
        /// Note: EOF is NOT an error. read/pread return 0 on EOF.
        case io(IO)

        /// File locking errors.
        case lock(Lock)

        /// Memory-related errors.
        case memory(Memory)

        /// System resource errors.
        case resource(Resource)

        /// A platform-specific error code that is not mapped to a semantic case.
        ///
        /// - Parameter code: The raw error code (errno on POSIX, GetLastError() on Windows).
        case platform(code: Int32)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let path):
            return path.description
        case .descriptor(let descriptor):
            return descriptor.description
        case .io(let io):
            return io.description
        case .lock(let lock):
            return lock.description
        case .memory(let memory):
            return memory.description
        case .resource(let resource):
            return resource.description
        case .platform(let code):
            return "platform error \(code)"
        }
    }
}

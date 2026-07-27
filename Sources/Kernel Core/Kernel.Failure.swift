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

// Wave 3.5-Final-Atomic (2026-05-02): explicit import required for
// `Kernel.Descriptor.Validity.Error` member access. Post-flip
// (`Kernel = POSIX.Kernel`), Kernel.Descriptor's defining module is
// POSIX_Kernel_Descriptor; Swift 6.x #MemberImportVisibility strictness
// requires explicit `public import` (not `internal`) since the enum case
// `handle(Kernel.Descriptor.Validity.Error)` is part of the public Failure type.
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public import POSIX_Kernel_Descriptor
#endif

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
    public enum Failure: Swift.Error, Sendable, Equatable {
        /// Path resolution errors.
        case path(Path.Resolution.Error)

        /// File descriptor/handle errors.
        case handle(Kernel.Descriptor.Validity.Error)

        /// I/O operation errors.
        /// Note: EOF is NOT an error. read/pread return 0 on EOF.
        case io(Kernel.IO.Error)

        /// File locking errors.
        case lock(Kernel.Lock.Error)

        /// Memory allocation errors.
        case memory(Memory.Allocation.Error)

        /// Permission errors.
        case permission(Kernel.Permission.Error)

        /// Storage space errors.
        case space(Kernel.Storage.Error)

        #if !os(Windows)
            /// Signal interruption errors.
            case signal(Kernel.Signal.Error)
        #endif

        /// Non-blocking operation errors.
        case blocking(Kernel.IO.Blocking.Error)

        /// Unmapped platform-specific errors.
        case platform(Error_Primitives.Error)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Failure: CustomStringConvertible {
    public var description: Swift.String {
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
        #if !os(Windows)
            case .signal(let error):
                return "signal: \(error)"
        #endif
        case .blocking(let error):
            return "blocking: \(error)"
        case .platform(let error):
            return "\(error)"
        }
    }
}

extension Kernel.Failure {
    public init?(
        _ code: Error_Primitives.Error.Code
    ) {
        // Try each domain in priority order
        if let e = Path.Resolution.Error(code: code) {
            self = .path(e)
            return
        }
        if let e = Kernel.Permission.Error(code: code) {
            self = .permission(e)
            return
        }
        if let e = Kernel.Descriptor.Validity.Error(code: code) {
            self = .handle(e)
            return
        }
        #if !os(Windows)
            if let e = Kernel.Signal.Error(code: code) {
                self = .signal(e)
                return
            }
        #endif
        if let e = Kernel.IO.Blocking.Error(code: code) {
            self = .blocking(e)
            return
        }
        if let e = Kernel.Storage.Error(code: code) {
            self = .space(e)
            return
        }
        if let e = Memory.Allocation.Error(code: code) {
            self = .memory(e)
            return
        }
        if let e = Kernel.IO.Error(code: code) {
            self = .io(e)
            return
        }
        if let e = Kernel.Lock.Error(code: code) {
            self = .lock(e)
            return
        }
        return nil
    }
}

extension Kernel.Failure {
    /// Returns the platform error message for a given error code.
    ///
    /// Delegates to platform-provided message properties:
    /// - POSIX: `Error_Primitives.Error.Code.posixMessage` (via swift-posix, strerror)
    /// - Windows: `Error_Primitives.Error.Code.win32Message` (via swift-windows, FormatMessageW)
    ///
    /// - Parameter code: The unified error code.
    /// - Returns: A human-readable error message, or `nil` if not available.
    public static func message(for code: Error_Primitives.Error.Code) -> Swift.String? {
        #if os(Windows)
            code.win32Message
        #else
            code.posixMessage
        #endif
    }
}

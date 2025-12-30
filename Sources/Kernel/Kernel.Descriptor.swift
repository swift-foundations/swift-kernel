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

#if os(Windows)
    public import WinSDK
#endif

extension Kernel {
    /// Raw file descriptor (POSIX) or HANDLE (Windows).
    ///
    /// This is the raw platform value with no ownership semantics.
    /// Higher layers (swift-io, swift-file-system) wrap this in `~Copyable` types
    /// to enforce ownership and prevent double-close.
    ///
    /// ## Thread Safety
    ///
    /// `Kernel.Descriptor` is `Sendable` (it's just an integer or pointer value).
    /// However, **sharing a descriptor across threads requires external synchronization**:
    ///
    /// - **Concurrent reads** on the same descriptor are safe if using positional I/O
    ///   (`pread`/`pwrite`). Sequential I/O (`read`/`write`) shares a file offset and
    ///   requires synchronization.
    /// - **Concurrent writes** always require synchronization unless using positional I/O.
    /// - **Close** invalidates the descriptor for all threads. Ensure no other thread
    ///   is using the descriptor before closing.
    ///
    /// The descriptor value itself can be safely passed between threads; it's the
    /// underlying kernel resource that requires coordination.
    #if os(Windows)
        public typealias Descriptor = HANDLE
    #else
        public typealias Descriptor = Int32
    #endif

    /// Invalid descriptor sentinel.
    ///
    /// - POSIX: `-1`
    /// - Windows: `INVALID_HANDLE_VALUE` (not nil)
    public static var invalidDescriptor: Descriptor {
        #if os(Windows)
            return INVALID_HANDLE_VALUE
        #else
            return -1
        #endif
    }

    /// Checks if a descriptor is valid (not the invalid sentinel).
    @inlinable
    public static func isValid(_ descriptor: Descriptor) -> Bool {
        #if os(Windows)
            return descriptor != INVALID_HANDLE_VALUE && descriptor != nil
        #else
            return descriptor >= 0
        #endif
    }
}

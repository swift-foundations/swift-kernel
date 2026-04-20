// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)

public import Kernel_Descriptor_Primitives
public import Kernel_File_Primitives
public import Kernel_Path_Primitives

// MARK: - Cross-platform Flush surface on POSIX

extension Kernel.File.Flush {
    /// Synchronizes a file's in-core state with storage device, automatically
    /// retrying on EINTR.
    ///
    /// Delegates to ``POSIX/Kernel/File/Flush/flush(_:)`` on POSIX (policy
    /// layer — EINTR retry) and ``Windows/Kernel/File/Flush/flush(_:)`` on
    /// Windows (`FlushFileBuffers` — Windows has no EINTR).
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/File/Flush/fsync(_:)`` on POSIX.
    ///
    /// - Parameter descriptor: The file descriptor.
    /// - Throws: ``Kernel/File/Flush/Error`` on failure (excluding EINTR on POSIX).
    @inlinable
    public static func flush(_ descriptor: borrowing Kernel.Descriptor) throws(Error) {
        try POSIX.Kernel.File.Flush.flush(descriptor)
    }

    /// Synchronizes file data to storage with the best available platform
    /// semantic, automatically retrying on EINTR.
    ///
    /// Single entry point for "data-only sync" semantics. Consumer code writes
    /// a single unconditional call site instead of a per-platform `#if`.
    ///
    /// Cross-platform contract:
    /// - **Linux**: ``ISO_9945/Kernel/File/Flush/fdatasync(_:)`` via the L3
    ///   policy layer — `fdatasync(2)`, data-only.
    /// - **Darwin**: ``ISO_9945/Kernel/File/Flush/barrierFsync(_:)`` via the
    ///   L3 policy layer — `fcntl(F_BARRIERFSYNC)`, closest "data-only-ish"
    ///   semantic.
    /// - **Windows**: `FlushFileBuffers` — Windows has no data-only
    ///   distinction, so this is a strictly-stronger full flush, never
    ///   weaker.
    ///
    /// - Parameter descriptor: The file descriptor.
    /// - Throws: ``Kernel/File/Flush/Error`` on failure (excluding EINTR on POSIX).
    @inlinable
    public static func data(_ descriptor: borrowing Kernel.Descriptor) throws(Error) {
        try POSIX.Kernel.File.Flush.data(descriptor)
    }

    /// Persists directory entries (rename visibility) to storage, automatically
    /// retrying on EINTR on POSIX.
    ///
    /// Single entry point for "directory sync" semantics. Consumer code writes
    /// a single unconditional call site instead of a `#if os(Windows)` branch
    /// separating the POSIX `open + fsync + close` recipe from a Windows
    /// no-op.
    ///
    /// Cross-platform contract:
    /// - **POSIX**: opens the directory `O_RDONLY` + `O_CLOEXEC`, calls
    ///   `fsync`, relies on `Kernel.Descriptor.deinit` for close. Both the
    ///   open and the flush retry on EINTR.
    /// - **Windows**: documented no-op. Windows does not expose a
    ///   directory-fsync primitive; rename durability is provided by the
    ///   rename itself plus subsequent `FlushFileBuffers` on affected files.
    ///
    /// - Parameter path: The directory path (borrowed view).
    /// - Throws: ``Kernel/File/Flush/Error`` on failure.
    @inlinable
    public static func directory(path: borrowing Kernel.Path.View) throws(Error) {
        try POSIX.Kernel.File.Flush.directory(path: path)
    }
}

#endif

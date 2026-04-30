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

public import Kernel_File_Primitives

// MARK: - Cross-platform Write surface on POSIX
//
// On POSIX the raw `write(2)` / `pwrite(2)` syscalls return EINTR when a
// signal interrupts the call. ``POSIX/Kernel/IO/Write`` in swift-posix (L3
// policy layer) wraps each overload in a `while true { … } catch where
// error.code.isInterrupted { continue }` loop so consumer code does not have
// to. `writeAll(_:from:)` additionally layers `EINTR` retry on top of the
// partial-write loop that iso-9945 defines. These cross-platform entry
// points delegate to the L3 tier per [PLAT-ARCH-008e]; raw access without
// retry remains available via ``ISO_9945/Kernel/IO/Write/write(_:from:)``,
// ``ISO_9945/Kernel/IO/Write/pwrite(_:from:at:)``, and
// ``ISO_9945/Kernel/IO/Write/writeAll(_:from:)``.
//
// On Windows the namespace-alias `Windows.Kernel == Kernel` already exposes
// ``Windows/Kernel/IO/Write/write(_:from:)`` and
// `pwrite(_:from:at:)` as `Kernel.IO.Write.write`/`pwrite` via
// swift-windows-standard (L2). Windows has no `EINTR` and swift-windows
// hosts no L3 policy wrapper for Write — the "L3 platform tier empty"
// exception in [PLAT-ARCH-008e] applies, so no companion
// `+CrossPlatform.Windows.swift` file is needed.

extension Kernel.IO.Write {
    /// Writes bytes from a raw buffer to a file descriptor, automatically
    /// retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Write/write(_:from:)`` on POSIX
    /// (policy layer — `EINTR` retry).
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/IO/Write/write(_:from:)``.
    ///
    /// May return fewer bytes than `buffer.count`; consumers needing
    /// "all or error" semantics should use ``writeAll(_:from:)-raw-overload``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - buffer: The buffer to write from.
    /// - Returns: Number of bytes written.
    /// - Throws: ``Kernel/IO/Write/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func write(
        _ descriptor: borrowing Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Error) -> Int {
        try unsafe POSIX.Kernel.IO.Write.write(descriptor, from: buffer)
    }

    /// Writes bytes from a span to a file descriptor, automatically retrying
    /// on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Write/write(_:from:)-span-overload``
    /// on POSIX.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - span: The span containing bytes to write.
    /// - Returns: Number of bytes written.
    /// - Throws: ``Kernel/IO/Write/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func write(
        _ descriptor: borrowing Kernel.Descriptor,
        from span: Span<UInt8>
    ) throws(Error) -> Int {
        try POSIX.Kernel.IO.Write.write(descriptor, from: span)
    }

    /// Writes bytes from a raw buffer to a file descriptor at a specific
    /// offset, automatically retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Write/pwrite(_:from:at:)`` on POSIX.
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/IO/Write/pwrite(_:from:at:)``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - buffer: The buffer to write from.
    ///   - offset: The file offset to write at.
    /// - Returns: Number of bytes written.
    /// - Throws: ``Kernel/IO/Write/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func pwrite(
        _ descriptor: borrowing Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer,
        at offset: Kernel.File.Offset
    ) throws(Error) -> Int {
        try unsafe POSIX.Kernel.IO.Write.pwrite(descriptor, from: buffer, at: offset)
    }

    /// Writes bytes from a span to a file descriptor at a specific offset,
    /// automatically retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Write/pwrite(_:from:at:)-span-overload``
    /// on POSIX.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - span: The span containing bytes to write.
    ///   - offset: The file offset to write at.
    /// - Returns: Number of bytes written.
    /// - Throws: ``Kernel/IO/Write/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func pwrite(
        _ descriptor: borrowing Kernel.Descriptor,
        from span: Span<UInt8>,
        at offset: Kernel.File.Offset
    ) throws(Error) -> Int {
        try POSIX.Kernel.IO.Write.pwrite(descriptor, from: span, at: offset)
    }

    /// Writes every byte of a raw buffer to a file descriptor, looping over
    /// partial writes and automatically retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Write/writeAll(_:from:)`` on POSIX,
    /// which layers `EINTR` retry on top of iso-9945's partial-write loop.
    ///
    /// Raw access (partial-write loop without retry) is available via
    /// ``ISO_9945/Kernel/IO/Write/writeAll(_:from:)``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - buffer: The buffer to write from.
    /// - Throws: ``Kernel/IO/Write/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func writeAll(
        _ descriptor: borrowing Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Error) {
        try unsafe POSIX.Kernel.IO.Write.writeAll(descriptor, from: buffer)
    }

    /// Writes every byte of a span to a file descriptor, looping over partial
    /// writes and automatically retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Write/writeAll(_:from:)-span-overload``
    /// on POSIX.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - span: The span containing bytes to write.
    /// - Throws: ``Kernel/IO/Write/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func writeAll(
        _ descriptor: borrowing Kernel.Descriptor,
        from span: Span<UInt8>
    ) throws(Error) {
        try POSIX.Kernel.IO.Write.writeAll(descriptor, from: span)
    }
}

#endif

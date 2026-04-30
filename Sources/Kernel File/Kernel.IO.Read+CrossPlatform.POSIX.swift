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


// MARK: - Cross-platform Read surface on POSIX
//
// On POSIX the raw `read(2)` / `pread(2)` syscalls return EINTR when a signal
// interrupts the call. ``POSIX/Kernel/IO/Read`` in swift-posix (L3 policy
// layer) wraps each overload in a `while true { … } catch where
// error.code.isInterrupted { continue }` loop so that consumer code does not
// have to. These cross-platform entry points delegate to that policy layer
// per [PLAT-ARCH-008e]; raw access without retry remains available via
// ``ISO_9945/Kernel/IO/Read/read(_:into:)`` and
// ``ISO_9945/Kernel/IO/Read/pread(_:into:at:)``.
//
// On Windows the namespace-alias `Windows.Kernel == Kernel` already exposes
// ``Windows/Kernel/IO/Read/read(_:into:)`` and `pread(_:into:at:)` as
// `Kernel.IO.Read.read`/`pread` via swift-windows-standard (L2). Windows has
// no `EINTR` and swift-windows hosts no L3 policy wrapper for Read — the
// "L3 platform tier empty" exception in [PLAT-ARCH-008e] applies, so no
// companion `+CrossPlatform.Windows.swift` file is needed.

extension Kernel.IO.Read {
    /// Reads bytes from a file descriptor into a raw buffer, automatically
    /// retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Read/read(_:into:)`` on POSIX (policy
    /// layer — `EINTR` retry).
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/IO/Read/read(_:into:)``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - buffer: The buffer to read into.
    /// - Returns: Number of bytes read; `0` on `EOF`.
    /// - Throws: ``Kernel/IO/Read/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func read(
        _ descriptor: borrowing Kernel.Descriptor,
        into buffer: UnsafeMutableRawBufferPointer
    ) throws(Error) -> Int {
        try unsafe POSIX.Kernel.IO.Read.read(descriptor, into: buffer)
    }

    /// Reads bytes from a file descriptor into a mutable span, automatically
    /// retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Read/read(_:into:)-span-overload`` on
    /// POSIX. The span adapter forwards to the raw-buffer path under the
    /// hood; retry happens once per inner syscall, not once per outer call.
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/IO/Read/read(_:into:)-span-overload``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - span: The mutable span to read into.
    /// - Returns: Number of bytes read; `0` on `EOF`.
    /// - Throws: ``Kernel/IO/Read/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func read(
        _ descriptor: borrowing Kernel.Descriptor,
        into span: inout MutableSpan<UInt8>
    ) throws(Error) -> Int {
        try POSIX.Kernel.IO.Read.read(descriptor, into: &span)
    }

    /// Reads bytes from a file descriptor at a specific offset into a raw
    /// buffer, automatically retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Read/pread(_:into:at:)`` on POSIX
    /// (policy layer — `EINTR` retry).
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/IO/Read/pread(_:into:at:)``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - buffer: The buffer to read into.
    ///   - offset: The file offset to read from.
    /// - Returns: Number of bytes read; `0` on `EOF`.
    /// - Throws: ``Kernel/IO/Read/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func pread(
        _ descriptor: borrowing Kernel.Descriptor,
        into buffer: UnsafeMutableRawBufferPointer,
        at offset: Kernel.File.Offset
    ) throws(Error) -> Int {
        try unsafe POSIX.Kernel.IO.Read.pread(descriptor, into: buffer, at: offset)
    }

    /// Reads bytes from a file descriptor at a specific offset into a mutable
    /// span, automatically retrying on `EINTR`.
    ///
    /// Delegates to ``POSIX/Kernel/IO/Read/pread(_:into:at:)-span-overload``
    /// on POSIX.
    ///
    /// Raw access without retry is available via
    /// ``ISO_9945/Kernel/IO/Read/pread(_:into:at:)-span-overload``.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - span: The mutable span to read into.
    ///   - offset: The file offset to read from.
    /// - Returns: Number of bytes read; `0` on `EOF`.
    /// - Throws: ``Kernel/IO/Read/Error`` on failure (excluding `EINTR`).
    @inlinable
    public static func pread(
        _ descriptor: borrowing Kernel.Descriptor,
        into span: inout MutableSpan<UInt8>,
        at offset: Kernel.File.Offset
    ) throws(Error) -> Int {
        try POSIX.Kernel.IO.Read.pread(descriptor, into: &span, at: offset)
    }
}

#endif

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

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

    public import Path_Primitives

    // MARK: - Cross-platform Flush surface on POSIX
    //
    // `Kernel.File.Flush.flush(_:)` resolves through `POSIX.Kernel.File.Flush.flush(_:)`
    // in swift-posix per [PLAT-ARCH-008e].
    //
    // `data(_:)` and `directory(path:)` are cross-platform intent names. The
    // POSIX side composes the per-platform L3 wrapper: Linux's `fdatasync` via
    // `Linux.Kernel.File.Flush.data`, Darwin's `F_BARRIERFSYNC` via
    // `Darwin.Kernel.File.Flush.data`. Per [PLAT-ARCH-008e], the L3-unifier
    // composes its peer L3-policy/platform tier.

    extension Kernel.File.Flush {
        /// Synchronizes file data to storage with the best available POSIX
        /// platform semantic.
        ///
        /// - On Linux: `fdatasync(2)` — flushes data only, may skip metadata.
        /// - On Darwin: `F_BARRIERFSYNC` — barrier flush, weaker than `fcntl(F_FULLFSYNC)`
        ///   but stronger than `fsync(2)` for crash-safety on APFS.
        ///
        /// - Parameter descriptor: The file descriptor.
        /// - Throws: ``Kernel/File/Flush/Error`` on failure.
        @inlinable
        public static func data(_ descriptor: borrowing Kernel.Descriptor) throws(Error) {
            try ISO_9945.Kernel.File.Flush.data(descriptor)
        }

        /// Synchronizes a directory to persist rename / unlink operations.
        ///
        /// Opens the directory and calls `fsync(2)` on the descriptor — the POSIX
        /// idiom for ensuring a rename or unlink within the directory is durably
        /// recorded.
        ///
        /// - Parameter path: The directory path.
        /// - Throws: ``Kernel/File/Flush/Error`` on failure.
        @inlinable
        public static func directory(path: borrowing Path.Borrowed) throws(Error) {
            try POSIX.Kernel.File.Flush.directory(path: path)
        }
    }

#endif

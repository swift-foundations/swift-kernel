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

#if os(Windows)

    public import Path_Primitives

    // MARK: - Cross-platform Flush surface on Windows
    //
    // `Kernel.File.Flush.flush(_:)` is NOT defined here; it is inherited from
    // `Windows.`32`.Kernel.File.Flush.flush(_:)` in swift-windows-32 (L2) per
    // the Wave 2 Tier 1a sub-namespace migration ([PLAT-ARCH-008k]). Windows
    // has no EINTR, so no L3 policy wrapper exists in swift-windows — the
    // [PLAT-ARCH-008e] exception applies: if the L3 platform tier is empty,
    // the unifier MAY delegate to L2 spec directly.
    //
    // `data(_:)` and `directory(path:)` are new cross-platform intent names that
    // do not exist at L2, so this file adds them with Windows semantics.

    extension Kernel.File.Flush {
        /// Synchronizes file data to storage with the best available Windows
        /// semantic.
        ///
        /// On Windows, `FlushFileBuffers` flushes both data and metadata —
        /// Windows has no data-only distinction. This is strictly stronger than
        /// the Linux `fdatasync` semantic, never weaker. The "data-only" name
        /// names the cross-platform intent; on Windows it is implemented as a
        /// full flush.
        ///
        /// Delegates directly to `Windows.`32`.Kernel.File.Flush.flush(_:)` in
        /// swift-windows-32 (L2). The [PLAT-ARCH-008e] exception applies:
        /// Windows has no EINTR and no L3 policy wrapper.
        ///
        /// - Parameter descriptor: The file descriptor.
        /// - Throws: ``Kernel/File/Flush/Error`` on failure.
        @inlinable
        public static func data(_ descriptor: borrowing Kernel.Descriptor) throws(Error) {
            try Windows.`32`.Kernel.File.Flush.flush(descriptor)
        }

        /// Documented no-op on Windows.
        ///
        /// Windows does not expose a directory-fsync primitive. Rename durability
        /// is provided by the rename itself plus subsequent `FlushFileBuffers` on
        /// affected files. The signature matches the POSIX branch so consumers
        /// can call this unconditionally as part of a durable-rename recipe; the
        /// no-op is the documented Windows semantic, not a missing implementation.
        ///
        /// - Parameter path: The directory path (borrowed view; unused on Windows).
        /// - Throws: never.
        @inlinable
        public static func directory(path: borrowing Path.Borrowed) throws(Error) {
            _ = path
        }
    }

#endif

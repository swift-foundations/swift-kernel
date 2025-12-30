//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

extension Kernel {
    /// Filesystem statistics.
    ///
    /// Used by higher layers (swift-io) for Direct I/O capability probing
    /// and filesystem type detection.
    ///
    /// ## Platform Differences
    ///
    /// The `type` field has different semantics across platforms:
    /// - **POSIX**: Filesystem magic number (e.g., 0x9123683E for Btrfs, 0x58465342 for XFS).
    ///   Use this to detect filesystem capabilities.
    /// - **Windows**: Volume serial number, which identifies a specific volume instance.
    ///   Use `fsTypeName` (e.g., "NTFS", "FAT32") for filesystem type detection on Windows.
    ///
    /// For cross-platform filesystem type detection, prefer `fsTypeName` when available,
    /// falling back to `type` magic number comparison on POSIX systems.
    public struct Statfs: Sendable, Equatable, Hashable {
        /// Filesystem type identifier.
        ///
        /// - POSIX: `f_type` — Filesystem magic number (e.g., 0x9123683E for Btrfs).
        ///   These values are platform-specific and can be used to detect filesystem capabilities.
        /// - Windows: Volume serial number, which identifies the volume instance.
        ///   **Note**: This is NOT a filesystem type. Use `fsTypeName` for type detection on Windows.
        ///
        /// - Important: The semantic meaning differs between platforms. For portable
        ///   filesystem type detection, use `fsTypeName` when available.
        public let type: UInt64

        /// Optimal transfer block size in bytes.
        public let blockSize: UInt64

        /// Total data blocks in filesystem.
        public let blocks: UInt64

        /// Free blocks in filesystem.
        public let freeBlocks: UInt64

        /// Free blocks available to unprivileged user.
        public let availableBlocks: UInt64

        /// Total file nodes (inodes) in filesystem.
        public let files: UInt64

        /// Free file nodes in filesystem.
        public let freeFiles: UInt64

        /// Filesystem ID.
        public let fsid: UInt64

        /// Maximum length of filenames.
        public let nameMax: UInt64

        /// Filesystem type name.
        ///
        /// - Darwin: `f_fstypename` (e.g., "apfs", "hfs", "nfs")
        /// - Linux: Not available (derived from `type` if needed)
        /// - Windows: Filesystem name from `GetVolumeInformationW` (e.g., "NTFS", "FAT32")
        ///
        /// This field is `nil` when the filesystem type name is not available.
        public let fsTypeName: String?

        /// Creates a Statfs with the given values.
        public init(
            type: UInt64,
            blockSize: UInt64,
            blocks: UInt64,
            freeBlocks: UInt64,
            availableBlocks: UInt64,
            files: UInt64,
            freeFiles: UInt64,
            fsid: UInt64,
            nameMax: UInt64,
            fsTypeName: String? = nil
        ) {
            self.type = type
            self.blockSize = blockSize
            self.blocks = blocks
            self.freeBlocks = freeBlocks
            self.availableBlocks = availableBlocks
            self.files = files
            self.freeFiles = freeFiles
            self.fsid = fsid
            self.nameMax = nameMax
            self.fsTypeName = fsTypeName
        }
    }
}

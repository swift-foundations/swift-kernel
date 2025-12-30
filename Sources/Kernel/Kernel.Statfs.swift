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
    public struct Statfs: Sendable, Equatable, Hashable {
        /// Filesystem type identifier.
        ///
        /// - POSIX: `f_type` (e.g., 0x9123683E for Btrfs, 0x58465342 for XFS)
        /// - Windows: Volume serial number
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
            nameMax: UInt64
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
        }
    }
}

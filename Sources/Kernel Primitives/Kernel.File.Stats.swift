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

extension Kernel.File {
    /// File metadata from stat/fstat syscalls.
    ///
    /// This is a minimal, cross-platform representation of file metadata.
    /// Platform-specific fields are normalized to common types.
    public struct Stats: Sendable, Equatable {
        /// File size in bytes.
        public let size: Kernel.File.Size

        /// File type (regular, directory, symlink, etc.).
        public let type: Kind

        /// POSIX file permissions (mode_t lower 12 bits).
        ///
        /// On Windows, this is synthesized from file attributes.
        public let permissions: UInt16

        /// Owner user ID.
        ///
        /// On Windows, this is always 0.
        public let uid: Kernel.User.ID

        /// Owner group ID.
        ///
        /// On Windows, this is always 0.
        public let gid: Kernel.Group.ID

        /// Inode number.
        ///
        /// On Windows, this is synthesized from file ID.
        public let inode: Kernel.Inode

        /// Device ID.
        ///
        /// On Windows, this is synthesized from volume serial number.
        public let device: Kernel.Device

        /// Number of hard links.
        public let linkCount: Kernel.Link.Count

        /// Last access time.
        public let accessTime: Kernel.Time

        /// Last modification time.
        public let modificationTime: Kernel.Time

        /// Status change time (POSIX) or last write time (Windows).
        ///
        /// On POSIX, this is `st_ctime` - the time of last status change (metadata or data).
        /// On Windows, this is `ftLastWriteTime` - the closest approximation, as Windows
        /// does not track metadata changes separately.
        ///
        /// - Note: This differs from some implementations that use `ftCreationTime`.
        ///   We use `ftLastWriteTime` because it better matches POSIX ctime semantics
        ///   (it updates when the file is modified, whereas creation time never changes).
        public let changeTime: Kernel.Time

        /// Creates a Stat value.
        @inlinable
        public init(
            size: Kernel.File.Size,
            type: Kind,
            permissions: UInt16,
            uid: Kernel.User.ID,
            gid: Kernel.Group.ID,
            inode: Kernel.Inode,
            device: Kernel.Device,
            linkCount: Kernel.Link.Count,
            accessTime: Kernel.Time,
            modificationTime: Kernel.Time,
            changeTime: Kernel.Time
        ) {
            self.size = size
            self.type = type
            self.permissions = permissions
            self.uid = uid
            self.gid = gid
            self.inode = inode
            self.device = device
            self.linkCount = linkCount
            self.accessTime = accessTime
            self.modificationTime = modificationTime
            self.changeTime = changeTime
        }
    }
}

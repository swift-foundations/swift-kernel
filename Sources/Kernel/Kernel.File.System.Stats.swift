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

public import SystemPackage

extension Kernel.File.System {
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
    public struct Stats: Sendable, Equatable, Hashable {
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

        /// Creates filesystem statistics with the given values.
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

// MARK: - Stats Error Type

extension Kernel.File.System.Stats {
    /// Error type for filesystem statistics operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        case path(Kernel.Path.Resolution.Error)
        case handle(Kernel.Handle.Error)
        case permission(Kernel.Permission.Error)
        case memory(Kernel.Memory.Error)
        case io(Kernel.IO.Error)
        case platform(Kernel.Platform.Error)
    }
}

extension Kernel.File.System.Stats.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let e): return "path: \(e)"
        case .handle(let e): return "handle: \(e)"
        case .permission(let e): return "permission: \(e)"
        case .memory(let e): return "memory: \(e)"
        case .io(let e): return "io: \(e)"
        case .platform(let e): return "\(e)"
        }
    }
}

// MARK: - POSIX Implementation

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin

        @usableFromInline
        internal typealias PlatformStatfs = Darwin.statfs
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim

        @usableFromInline
        internal typealias PlatformStatfs = statfs
    #elseif canImport(Musl)
        public import Musl

        @usableFromInline
        internal typealias PlatformStatfs = statfs
    #endif

    extension Kernel.File.System.Stats.Error {
        @inlinable
        init(errno: Errno) {
            if let e = Kernel.Path.Resolution.Error(errno: errno) {
                self = .path(e)
                return
            }
            if let e = Kernel.Handle.Error(errno: errno) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Permission.Error(errno: errno) {
                self = .permission(e)
                return
            }
            if let e = Kernel.Memory.Error(errno: errno) {
                self = .memory(e)
                return
            }
            if let e = Kernel.IO.Error(errno: errno) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Platform.Error(errno: errno))
        }

        @inlinable
        static func current() -> Self {
            Self(errno: Errno(rawValue: errno))
        }
    }

    extension Kernel.File.System.Stats {
        /// Gets filesystem statistics for a path.
        ///
        /// - Parameter path: The path to get statistics for.
        /// - Returns: The filesystem statistics.
        /// - Throws: `Kernel.File.System.Stats.Error` on failure.
        @inlinable
        public static func get(path: FilePath) throws(Error) -> Kernel.File.System.Stats {
            try Kernel.withPlatformString(path) { (cString: UnsafePointer<CInterop.PlatformChar>) throws(Error) -> Kernel.File.System.Stats in
                try get(unsafePath: cString)
            }
        }

        /// Gets filesystem statistics for an unsafe path pointer.
        ///
        /// - Parameter unsafePath: A null-terminated C string path.
        /// - Returns: The filesystem statistics.
        /// - Throws: `Kernel.File.System.Stats.Error` on failure.
        @inlinable
        public static func get(unsafePath: UnsafePointer<CChar>) throws(Error) -> Kernel.File.System.Stats {
            var buf = PlatformStatfs()
            let result = statfs(unsafePath, &buf)
            guard result == 0 else {
                throw .current()
            }
            return Kernel.File.System.Stats(from: buf)
        }

        /// Gets filesystem statistics for a file descriptor.
        ///
        /// - Parameter descriptor: The file descriptor to get statistics for.
        /// - Returns: The filesystem statistics.
        /// - Throws: `Kernel.File.System.Stats.Error` on failure.
        @inlinable
        public static func get(descriptor: Kernel.Descriptor) throws(Error) -> Kernel.File.System.Stats {
            guard descriptor.isValid else {
                throw .handle(.invalid)
            }
            var buf = PlatformStatfs()
            let result = fstatfs(descriptor.rawValue, &buf)
            guard result == 0 else {
                throw .current()
            }
            return Kernel.File.System.Stats(from: buf)
        }

        /// Creates filesystem statistics from the platform's statfs struct.
        @usableFromInline
        init(from buf: PlatformStatfs) {
            #if canImport(Darwin)
                self.init(
                    type: UInt64(buf.f_type),
                    blockSize: UInt64(buf.f_bsize),
                    blocks: UInt64(buf.f_blocks),
                    freeBlocks: UInt64(buf.f_bfree),
                    availableBlocks: UInt64(buf.f_bavail),
                    files: UInt64(buf.f_files),
                    freeFiles: UInt64(buf.f_ffree),
                    fsid: UInt64(buf.f_fsid.val.0) | (UInt64(buf.f_fsid.val.1) << 32),
                    nameMax: UInt64(NAME_MAX),
                    fsTypeName: withUnsafeBytes(of: buf.f_fstypename) { ptr in
                        String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
                    }
                )
            #else
                self.init(
                    type: UInt64(bitPattern: Int64(buf.f_type)),
                    blockSize: UInt64(buf.f_bsize),
                    blocks: UInt64(buf.f_blocks),
                    freeBlocks: UInt64(buf.f_bfree),
                    availableBlocks: UInt64(buf.f_bavail),
                    files: UInt64(buf.f_files),
                    freeFiles: UInt64(buf.f_ffree),
                    fsid: UInt64(buf.f_fsid.__val.0) | (UInt64(buf.f_fsid.__val.1) << 32),
                    nameMax: UInt64(buf.f_namelen),
                    fsTypeName: nil
                )
            #endif
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.File.System.Stats.Error {
        @inlinable
        init(windowsError error: DWORD) {
            if let e = Kernel.Path.Resolution.Error(windowsError: error) {
                self = .path(e)
                return
            }
            if let e = Kernel.Handle.Error(windowsError: error) {
                self = .handle(e)
                return
            }
            if let e = Kernel.Permission.Error(windowsError: error) {
                self = .permission(e)
                return
            }
            if let e = Kernel.Memory.Error(windowsError: error) {
                self = .memory(e)
                return
            }
            if let e = Kernel.IO.Error(windowsError: error) {
                self = .io(e)
                return
            }
            self = .platform(Kernel.Platform.Error(windowsError: error))
        }

        @inlinable
        static func current() -> Self {
            Self(windowsError: GetLastError())
        }
    }

    extension Kernel.File.System.Stats {
        /// Gets filesystem statistics for a path.
        ///
        /// - Parameter path: The path to get statistics for.
        /// - Returns: The filesystem statistics.
        /// - Throws: `Kernel.File.System.Stats.Error` on failure.
        @inlinable
        public static func get(path: FilePath) throws(Error) -> Kernel.File.System.Stats {
            try Kernel.withPlatformString(path) { (wpath: UnsafePointer<CInterop.PlatformChar>) throws(Error) -> Kernel.File.System.Stats in
                try get(unsafePath: wpath)
            }
        }

        /// Gets filesystem statistics for an unsafe path pointer.
        ///
        /// - Parameter unsafePath: A null-terminated wide string path.
        /// - Returns: The filesystem statistics.
        /// - Throws: `Kernel.File.System.Stats.Error` on failure.
        @inlinable
        public static func get(unsafePath: UnsafePointer<WCHAR>) throws(Error) -> Kernel.File.System.Stats {
            var sectorsPerCluster: DWORD = 0
            var bytesPerSector: DWORD = 0
            var freeClusters: DWORD = 0
            var totalClusters: DWORD = 0

            guard GetDiskFreeSpaceW(unsafePath, &sectorsPerCluster, &bytesPerSector, &freeClusters, &totalClusters) else {
                throw .current()
            }

            let blockSize = UInt64(sectorsPerCluster) * UInt64(bytesPerSector)

            // Get volume information for type name
            var volumeSerial: DWORD = 0
            var maxComponentLength: DWORD = 0
            var fsFlags: DWORD = 0
            var fsNameBuffer = [WCHAR](repeating: 0, count: 256)

            let gotVolumeInfo = GetVolumeInformationW(
                unsafePath,
                nil,
                0,
                &volumeSerial,
                &maxComponentLength,
                &fsFlags,
                &fsNameBuffer,
                DWORD(fsNameBuffer.count)
            )

            let fsTypeName: String? =
                gotVolumeInfo
                ? {
                    if let nullIndex = fsNameBuffer.firstIndex(of: 0) {
                        return String(decoding: fsNameBuffer[..<nullIndex], as: UTF16.self)
                    }
                    return String(decoding: fsNameBuffer, as: UTF16.self)
                }() : nil

            return Kernel.File.System.Stats(
                type: UInt64(volumeSerial),
                blockSize: blockSize,
                blocks: UInt64(totalClusters),
                freeBlocks: UInt64(freeClusters),
                availableBlocks: UInt64(freeClusters),
                files: 0,
                freeFiles: 0,
                fsid: UInt64(volumeSerial),
                nameMax: UInt64(maxComponentLength),
                fsTypeName: fsTypeName
            )
        }
    }
#endif

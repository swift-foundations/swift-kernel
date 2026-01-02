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
    internal import WinSDK
#else
    internal import SystemPackage

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif
#endif

extension Kernel.File {
    /// Gets file metadata for an open file descriptor.
    ///
    /// - Parameter descriptor: The file descriptor to stat.
    /// - Returns: File metadata.
    /// - Throws: `Kernel.Error` if the syscall fails.
    @inlinable
    public static func stat(_ descriptor: Kernel.Descriptor) throws(Kernel.Error) -> Kernel.Stat {
        #if os(Windows)
            return try statWindows(descriptor)
        #else
            return try statPosix(descriptor)
        #endif
    }
}

// MARK: - POSIX Implementation

#if !os(Windows)

    extension Kernel.File {
        @usableFromInline
        internal static func statPosix(_ descriptor: Kernel.Descriptor) throws(Kernel.Error) -> Kernel.Stat {
            var sb = PlatformStat()
            guard _cFstat(descriptor.rawValue, &sb) == 0 else {
                throw .platform(code: errno, message: "fstat failed")
            }
            return Kernel.Stat(from: sb)
        }
    }

    extension Kernel.Stat {
        /// Creates a Kernel.Stat from a POSIX stat structure.
        @usableFromInline
        internal init(from sb: PlatformStat) {
            #if canImport(Darwin)
                let atime = Kernel.Time(seconds: Int64(sb.st_atimespec.tv_sec), nanoseconds: Int32(sb.st_atimespec.tv_nsec))
                let mtime = Kernel.Time(seconds: Int64(sb.st_mtimespec.tv_sec), nanoseconds: Int32(sb.st_mtimespec.tv_nsec))
                let ctime = Kernel.Time(seconds: Int64(sb.st_ctimespec.tv_sec), nanoseconds: Int32(sb.st_ctimespec.tv_nsec))
            #else
                let atime = Kernel.Time(seconds: Int64(sb.st_atim.tv_sec), nanoseconds: Int32(sb.st_atim.tv_nsec))
                let mtime = Kernel.Time(seconds: Int64(sb.st_mtim.tv_sec), nanoseconds: Int32(sb.st_mtim.tv_nsec))
                let ctime = Kernel.Time(seconds: Int64(sb.st_ctim.tv_sec), nanoseconds: Int32(sb.st_ctim.tv_nsec))
            #endif

            self.init(
                size: Int64(sb.st_size),
                type: Kind(mode: sb.st_mode),
                permissions: UInt16(sb.st_mode & 0o7777),
                uid: UInt32(sb.st_uid),
                gid: UInt32(sb.st_gid),
                inode: UInt64(sb.st_ino),
                device: UInt64(sb.st_dev),
                linkCount: UInt32(sb.st_nlink),
                accessTime: atime,
                modificationTime: mtime,
                changeTime: ctime
            )
        }
    }

    extension Kernel.Stat.Kind {
        /// Creates a file type from POSIX st_mode.
        @usableFromInline
        internal init(mode: mode_t) {
            let fileType = mode & S_IFMT
            switch fileType {
            case S_IFREG:
                self = .regular
            case S_IFDIR:
                self = .directory
            case S_IFLNK:
                self = .link(.symbolic)
            case S_IFBLK:
                self = .device(.block)
            case S_IFCHR:
                self = .device(.character)
            case S_IFIFO:
                self = .fifo
            case S_IFSOCK:
                self = .socket
            default:
                self = .unknown
            }
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)

    extension Kernel.File {
        @usableFromInline
        internal static func statWindows(_ descriptor: Kernel.Descriptor) throws(Kernel.Error) -> Kernel.Stat {
            var info = BY_HANDLE_FILE_INFORMATION()
            guard GetFileInformationByHandle(descriptor.rawValue, &info) else {
                throw Kernel.Error.windows(GetLastError())
            }

            let size = (Int64(info.nFileSizeHigh) << 32) | Int64(info.nFileSizeLow)

            let type: Kernel.Stat.Kind
            if (info.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                type = .directory
            } else if (info.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                // Could be symlink or junction - simplified to symlink
                type = .link(.symbolic)
            } else {
                type = .regular
            }

            // Synthesize POSIX-like permissions from Windows attributes
            var permissions: UInt16 = 0o644  // Default: rw-r--r--
            if (info.dwFileAttributes & DWORD(FILE_ATTRIBUTE_READONLY)) != 0 {
                permissions = 0o444  // r--r--r--
            }
            if (info.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                permissions |= 0o111  // Add execute for directories
            }

            let inode = (UInt64(info.nFileIndexHigh) << 32) | UInt64(info.nFileIndexLow)

            return Kernel.Stat(
                size: size,
                type: type,
                permissions: permissions,
                uid: 0,
                gid: 0,
                inode: inode,
                device: UInt64(info.dwVolumeSerialNumber),
                linkCount: UInt32(info.nNumberOfLinks),
                accessTime: Kernel.Time(from: info.ftLastAccessTime),
                modificationTime: Kernel.Time(from: info.ftLastWriteTime),
                changeTime: Kernel.Time(from: info.ftLastWriteTime)
            )
        }
    }

    extension Kernel.Time {
        /// Creates a time from a Windows FILETIME.
        ///
        /// FILETIME is 100-nanosecond intervals since January 1, 1601.
        /// We convert to Unix epoch (January 1, 1970).
        @usableFromInline
        internal init(from ft: FILETIME) {
            // FILETIME to 100-nanosecond intervals
            let intervals = (Int64(ft.dwHighDateTime) << 32) | Int64(ft.dwLowDateTime)
            // Offset between Windows epoch (1601) and Unix epoch (1970) in 100-ns intervals
            let epochOffset: Int64 = 116444736000000000
            let unixIntervals = intervals - epochOffset
            let seconds = unixIntervals / 10_000_000
            let nanoseconds = Int32((unixIntervals % 10_000_000) * 100)
            self.init(seconds: seconds, nanoseconds: nanoseconds)
        }
    }

#endif

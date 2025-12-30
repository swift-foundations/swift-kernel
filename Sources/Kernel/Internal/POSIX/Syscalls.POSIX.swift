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

#if !os(Windows)
public import SystemPackage

#if canImport(Darwin)
public import Darwin
#elseif canImport(Glibc)
public import Glibc
#elseif canImport(Musl)
public import Musl
#endif

// MARK: - File Operations (FilePath overloads - recommended)

extension Kernel.Syscalls {
    /// Opens a file at the specified path.
    ///
    /// This is the recommended, safe overload using `FilePath` from swift-system.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - mode: The access mode (read, write, or read-write).
    ///   - options: Additional open options.
    ///   - permissions: POSIX file permissions (e.g., 0o644) for newly created files.
    /// - Returns: A file descriptor for the opened file.
    /// - Throws: `Kernel.Error` on failure.
    public static func open(
        path: FilePath,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        do {
            return try path.withPlatformString { cString in
                try open(
                    unsafePath: cString,
                    mode: mode,
                    options: options,
                    permissions: permissions
                )
            }
        } catch let error as Kernel.Error {
            throw error
        } catch {
            // FilePath.withPlatformString shouldn't throw other errors
            throw .platform(code: -1, message: "Unexpected error: \(error)")
        }
    }

    /// Gets file metadata for a path.
    ///
    /// This is the recommended, safe overload using `FilePath` from swift-system.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - followSymlinks: If `true`, follows symbolic links (stat). If `false`, gets link info (lstat).
    /// - Returns: File metadata.
    /// - Throws: `Kernel.Error` on failure.
    public static func stat(
        path: FilePath,
        followSymlinks: Bool
    ) throws(Kernel.Error) -> Kernel.Stat {
        do {
            return try path.withPlatformString { cString in
                try stat(unsafePath: cString, followSymlinks: followSymlinks)
            }
        } catch let error as Kernel.Error {
            throw error
        } catch {
            throw .platform(code: -1, message: "Unexpected error: \(error)")
        }
    }
}

// MARK: - File Operations (Kernel.Path overloads)

extension Kernel.Syscalls {
    /// Opens a file at the specified path.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode (read, write, or read-write).
    ///   - options: Additional open options.
    ///   - permissions: POSIX file permissions (e.g., 0o644) for newly created files.
    /// - Returns: A file descriptor for the opened file.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func open(
        path: borrowing Kernel.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        try open(
            unsafePath: path.cString,
            mode: mode,
            options: options,
            permissions: permissions
        )
    }

    /// Gets file metadata for a path.
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - followSymlinks: If `true`, follows symbolic links (stat). If `false`, gets link info (lstat).
    /// - Returns: File metadata.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func stat(
        path: borrowing Kernel.Path,
        followSymlinks: Bool
    ) throws(Kernel.Error) -> Kernel.Stat {
        try stat(unsafePath: path.cString, followSymlinks: followSymlinks)
    }
}

// MARK: - File Operations (unsafe pointer overloads - escape hatch)

extension Kernel.Syscalls {
    /// Opens a file at the specified path.
    ///
    /// - Warning: This is an unsafe escape hatch. Prefer the `FilePath` overload.
    ///
    /// - Parameters:
    ///   - unsafePath: A null-terminated C string path. Caller must ensure validity.
    ///   - mode: The access mode (read, write, or read-write).
    ///   - options: Additional open options.
    ///   - permissions: POSIX file permissions (e.g., 0o644) for newly created files.
    /// - Returns: A file descriptor for the opened file.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func open(
        unsafePath: UnsafePointer<CChar>,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        let flags = mode.posixFlags | options.posixFlags

        let fd: Int32
        if options.contains(.create) {
            #if canImport(Darwin)
            fd = Darwin.open(unsafePath, flags, mode_t(permissions))
            #elseif canImport(Glibc)
            fd = Glibc.open(unsafePath, flags, mode_t(permissions))
            #elseif canImport(Musl)
            fd = Musl.open(unsafePath, flags, mode_t(permissions))
            #endif
        } else {
            #if canImport(Darwin)
            fd = Darwin.open(unsafePath, flags)
            #elseif canImport(Glibc)
            fd = Glibc.open(unsafePath, flags)
            #elseif canImport(Musl)
            fd = Musl.open(unsafePath, flags)
            #endif
        }

        guard fd >= 0 else {
            throw Kernel.Error.currentPosixError()
        }

        // Apply F_NOCACHE on macOS if requested
        #if canImport(Darwin)
        if options.contains(.cacheDisabled) {
            _ = fcntl(fd, F_NOCACHE, 1)
        }
        #endif

        return fd
    }

    /// Gets file metadata for a path.
    ///
    /// - Warning: This is an unsafe escape hatch. Prefer the `FilePath` overload.
    ///
    /// - Parameters:
    ///   - unsafePath: A null-terminated C string path. Caller must ensure validity.
    ///   - followSymlinks: If `true`, follows symbolic links (stat). If `false`, gets link info (lstat).
    /// - Returns: File metadata.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func stat(
        unsafePath: UnsafePointer<CChar>,
        followSymlinks: Bool
    ) throws(Kernel.Error) -> Kernel.Stat {
        var sb = PlatformStat()
        let result: Int32
        if followSymlinks {
            result = _cStat(unsafePath, &sb)
        } else {
            result = _cLstat(unsafePath, &sb)
        }
        guard result == 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return Kernel.Stat(posix: sb)
    }

    /// Closes a file descriptor.
    ///
    /// - Parameter descriptor: The file descriptor to close.
    /// - Throws: `Kernel.Error` on failure.
    ///
    /// - Note: EINTR is treated as "closed" per POSIX semantics. The descriptor
    ///   is no longer valid after this call returns, even if it throws.
    @inlinable
    public static func close(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) {
        #if canImport(Darwin)
        let result = Darwin.close(descriptor)
        #elseif canImport(Glibc)
        let result = Glibc.close(descriptor)
        #elseif canImport(Musl)
        let result = Musl.close(descriptor)
        #endif

        if result == -1 {
            let error = errno
            // EINTR means the fd is closed, but the syscall was interrupted
            // The fd is NOT valid after close(), even on EINTR
            if error != EINTR {
                throw Kernel.Error.posix(error)
            }
        }
    }

    /// Reads bytes from a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - buffer: The buffer to read into.
    /// - Returns: The number of bytes read. Returns 0 on EOF (not an error).
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func read(
        _ descriptor: Kernel.Descriptor,
        into buffer: UnsafeMutableRawBufferPointer
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }

        #if canImport(Darwin)
        let result = Darwin.read(descriptor, baseAddress, buffer.count)
        #elseif canImport(Glibc)
        let result = Glibc.read(descriptor, baseAddress, buffer.count)
        #elseif canImport(Musl)
        let result = Musl.read(descriptor, baseAddress, buffer.count)
        #endif

        guard result >= 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    /// Writes bytes to a file descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - buffer: The buffer containing data to write.
    /// - Returns: The number of bytes written (may be less than buffer.count).
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func write(
        _ descriptor: Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }

        #if canImport(Darwin)
        let result = Darwin.write(descriptor, baseAddress, buffer.count)
        #elseif canImport(Glibc)
        let result = Glibc.write(descriptor, baseAddress, buffer.count)
        #elseif canImport(Musl)
        let result = Musl.write(descriptor, baseAddress, buffer.count)
        #endif

        guard result >= 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    /// Reads bytes from a file descriptor at a specific offset.
    ///
    /// The file offset is not changed by this operation.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to read from.
    ///   - buffer: The buffer to read into.
    ///   - offset: The file offset to read from.
    /// - Returns: The number of bytes read. Returns 0 on EOF.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func pread(
        _ descriptor: Kernel.Descriptor,
        into buffer: UnsafeMutableRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }

        #if canImport(Darwin)
        let result = Darwin.pread(descriptor, baseAddress, buffer.count, off_t(offset))
        #elseif canImport(Glibc)
        let result = Glibc.pread(descriptor, baseAddress, buffer.count, off_t(offset))
        #elseif canImport(Musl)
        let result = Musl.pread(descriptor, baseAddress, buffer.count, off_t(offset))
        #endif

        guard result >= 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    /// Writes bytes to a file descriptor at a specific offset.
    ///
    /// The file offset is not changed by this operation.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor to write to.
    ///   - buffer: The buffer containing data to write.
    ///   - offset: The file offset to write at.
    /// - Returns: The number of bytes written (may be less than buffer.count).
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func pwrite(
        _ descriptor: Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }

        #if canImport(Darwin)
        let result = Darwin.pwrite(descriptor, baseAddress, buffer.count, off_t(offset))
        #elseif canImport(Glibc)
        let result = Glibc.pwrite(descriptor, baseAddress, buffer.count, off_t(offset))
        #elseif canImport(Musl)
        let result = Musl.pwrite(descriptor, baseAddress, buffer.count, off_t(offset))
        #endif

        guard result >= 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    /// Changes the file offset of a descriptor.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor.
    ///   - offset: The offset value.
    ///   - origin: The reference point for the offset.
    /// - Returns: The new absolute file offset.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func seek(
        _ descriptor: Kernel.Descriptor,
        offset: Int64,
        origin: Kernel.Seek.Origin
    ) throws(Kernel.Error) -> Int64 {
        let whence: Int32
        switch origin {
        case .start:
            whence = SEEK_SET
        case .current:
            whence = SEEK_CUR
        case .end:
            whence = SEEK_END
        }

        let result = lseek(descriptor, off_t(offset), whence)
        guard result >= 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return Int64(result)
    }

    /// Synchronizes a file's data and metadata to disk.
    ///
    /// - Parameter descriptor: The file descriptor.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func sync(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) {
        let result = fsync(descriptor)
        guard result == 0 else {
            throw Kernel.Error.currentPosixError()
        }
    }

    /// Truncates a file to a specified length.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor.
    ///   - length: The new file length.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func truncate(
        _ descriptor: Kernel.Descriptor,
        to length: Int64
    ) throws(Kernel.Error) {
        let result = ftruncate(descriptor, off_t(length))
        guard result == 0 else {
            throw Kernel.Error.currentPosixError()
        }
    }

    /// Duplicates a file descriptor.
    ///
    /// - Parameter descriptor: The file descriptor to duplicate.
    /// - Returns: A new file descriptor referring to the same file.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func duplicate(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        let result = dup(descriptor)
        guard result >= 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return result
    }

    // MARK: - Stat Operations

    /// Gets file metadata for an open file descriptor.
    ///
    /// - Parameter descriptor: The file descriptor.
    /// - Returns: File metadata.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func fstat(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) -> Kernel.Stat {
        var sb = PlatformStat()
        let result = _cFstat(descriptor, &sb)
        guard result == 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return Kernel.Stat(posix: sb)
    }

    // MARK: - Locking Operations

    /// Acquires a lock on a byte range.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor.
    ///   - range: The byte range to lock.
    ///   - exclusive: `true` for exclusive (write) lock, `false` for shared (read) lock.
    ///   - wait: `true` to block until lock is acquired, `false` to return immediately.
    /// - Returns: `true` if lock was acquired, `false` if `wait` is `false` and lock is held.
    /// - Throws: `Kernel.Error` on failure.
    ///
    /// ## Contract
    /// - `wait == false`: Returns `false` on contention (no throw). Returns `true` on success.
    /// - `wait == true`: Never returns `false`. Either succeeds or throws.
    @inlinable
    public static func lock(
        _ descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range,
        exclusive: Bool,
        wait: Bool
    ) throws(Kernel.Error) -> Bool {
        var fl = flock()
        fl.l_type = exclusive ? Int16(F_WRLCK) : Int16(F_RDLCK)
        fl.l_whence = Int16(SEEK_SET)

        switch range {
        case .file:
            // l_start = 0, l_len = 0 means "lock entire file to EOF"
            fl.l_start = 0
            fl.l_len = 0
        case .bytes(let start, let length):
            fl.l_start = off_t(start)
            fl.l_len = off_t(length)
        }

        let command = wait ? F_SETLKW : F_SETLK
        let result = fcntl(descriptor, command, &fl)

        if result == -1 {
            let err = errno
            // EAGAIN or EACCES means the lock is held (non-blocking case)
            if !wait && (err == EAGAIN || err == EACCES) {
                return false
            }
            throw Kernel.Error.posix(err)
        }
        return true
    }

    /// Releases a lock on a byte range.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor.
    ///   - range: The byte range to unlock.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func unlock(
        _ descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range
    ) throws(Kernel.Error) {
        var fl = flock()
        fl.l_type = Int16(F_UNLCK)
        fl.l_whence = Int16(SEEK_SET)

        switch range {
        case .file:
            fl.l_start = 0
            fl.l_len = 0
        case .bytes(let start, let length):
            fl.l_start = off_t(start)
            fl.l_len = off_t(length)
        }

        let result = fcntl(descriptor, F_SETLK, &fl)
        guard result != -1 else {
            throw Kernel.Error.currentPosixError()
        }
    }

    // MARK: - Filesystem Statistics

    /// Gets filesystem statistics for a path.
    ///
    /// - Parameter path: The file path.
    /// - Returns: Filesystem statistics.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func statfs(
        path: FilePath
    ) throws(Kernel.Error) -> Kernel.Statfs {
        do {
            return try path.withPlatformString { cString in
                try statfs(unsafePath: cString)
            }
        } catch let error as Kernel.Error {
            throw error
        } catch {
            throw .platform(code: -1, message: "Unexpected error: \(error)")
        }
    }

    /// Gets filesystem statistics for a path.
    ///
    /// - Parameter unsafePath: A null-terminated C string path.
    /// - Returns: Filesystem statistics.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func statfs(
        unsafePath: UnsafePointer<CChar>
    ) throws(Kernel.Error) -> Kernel.Statfs {
        var buf = PlatformStatfs()
        let result = _cStatfs(unsafePath, &buf)
        guard result == 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return Kernel.Statfs(posix: buf)
    }

    /// Gets filesystem statistics for an open file descriptor.
    ///
    /// - Parameter descriptor: The file descriptor.
    /// - Returns: Filesystem statistics.
    /// - Throws: `Kernel.Error` on failure.
    @inlinable
    public static func fstatfs(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) -> Kernel.Statfs {
        var buf = PlatformStatfs()
        let result = _cFstatfs(descriptor, &buf)
        guard result == 0 else {
            throw Kernel.Error.currentPosixError()
        }
        return Kernel.Statfs(posix: buf)
    }
}

// MARK: - Stat Helpers

// These helpers wrap the C stat functions to avoid name collision with Kernel.Syscalls.stat
// We use unqualified calls because Darwin.stat refers to the type, not the function
#if canImport(Darwin)
@usableFromInline
internal typealias PlatformStat = Darwin.stat

@usableFromInline
internal typealias PlatformStatfs = Darwin.statfs

@usableFromInline
internal func _cStat(_ path: UnsafePointer<CChar>, _ sb: inout PlatformStat) -> Int32 {
    stat(path, &sb)
}

@usableFromInline
internal func _cLstat(_ path: UnsafePointer<CChar>, _ sb: inout PlatformStat) -> Int32 {
    lstat(path, &sb)
}

@usableFromInline
internal func _cFstat(_ fd: Int32, _ sb: inout PlatformStat) -> Int32 {
    fstat(fd, &sb)
}

@usableFromInline
internal func _cStatfs(_ path: UnsafePointer<CChar>, _ buf: inout PlatformStatfs) -> Int32 {
    // Use unqualified call to avoid name collision with statfs type
    statfs(path, &buf)
}

@usableFromInline
internal func _cFstatfs(_ fd: Int32, _ buf: inout PlatformStatfs) -> Int32 {
    fstatfs(fd, &buf)
}
#elseif canImport(Glibc)
@usableFromInline
internal typealias PlatformStat = Glibc.stat

@usableFromInline
internal typealias PlatformStatfs = Glibc.statfs

@usableFromInline
internal func _cStat(_ path: UnsafePointer<CChar>, _ sb: inout PlatformStat) -> Int32 {
    stat(path, &sb)
}

@usableFromInline
internal func _cLstat(_ path: UnsafePointer<CChar>, _ sb: inout PlatformStat) -> Int32 {
    lstat(path, &sb)
}

@usableFromInline
internal func _cFstat(_ fd: Int32, _ sb: inout PlatformStat) -> Int32 {
    fstat(fd, &sb)
}

@usableFromInline
internal func _cStatfs(_ path: UnsafePointer<CChar>, _ buf: inout PlatformStatfs) -> Int32 {
    // Use unqualified call to avoid name collision with statfs type
    statfs(path, &buf)
}

@usableFromInline
internal func _cFstatfs(_ fd: Int32, _ buf: inout PlatformStatfs) -> Int32 {
    fstatfs(fd, &buf)
}
#elseif canImport(Musl)
@usableFromInline
internal typealias PlatformStat = Musl.stat

@usableFromInline
internal typealias PlatformStatfs = Musl.statfs

@usableFromInline
internal func _cStat(_ path: UnsafePointer<CChar>, _ sb: inout PlatformStat) -> Int32 {
    stat(path, &sb)
}

@usableFromInline
internal func _cLstat(_ path: UnsafePointer<CChar>, _ sb: inout PlatformStat) -> Int32 {
    lstat(path, &sb)
}

@usableFromInline
internal func _cFstat(_ fd: Int32, _ sb: inout PlatformStat) -> Int32 {
    fstat(fd, &sb)
}

@usableFromInline
internal func _cStatfs(_ path: UnsafePointer<CChar>, _ buf: inout PlatformStatfs) -> Int32 {
    // Use unqualified call to avoid name collision with statfs type
    statfs(path, &buf)
}

@usableFromInline
internal func _cFstatfs(_ fd: Int32, _ buf: inout PlatformStatfs) -> Int32 {
    fstatfs(fd, &buf)
}
#endif

// MARK: - Stat Conversion

extension Kernel.Stat {
    /// Creates a Stat from a POSIX stat structure.
    @inlinable
    init(posix sb: PlatformStat) {
        self.size = Int64(sb.st_size)
        self.type = Kind(posixMode: sb.st_mode)
        self.permissions = UInt16(sb.st_mode & 0o7777)
        self.uid = UInt32(sb.st_uid)
        self.gid = UInt32(sb.st_gid)
        self.inode = UInt64(sb.st_ino)
        self.device = UInt64(sb.st_dev)
        self.linkCount = UInt32(sb.st_nlink)

        #if canImport(Darwin)
        self.accessTime = Kernel.Time(
            seconds: Int64(sb.st_atimespec.tv_sec),
            nanoseconds: Int32(sb.st_atimespec.tv_nsec)
        )
        self.modificationTime = Kernel.Time(
            seconds: Int64(sb.st_mtimespec.tv_sec),
            nanoseconds: Int32(sb.st_mtimespec.tv_nsec)
        )
        self.changeTime = Kernel.Time(
            seconds: Int64(sb.st_ctimespec.tv_sec),
            nanoseconds: Int32(sb.st_ctimespec.tv_nsec)
        )
        #else
        self.accessTime = Kernel.Time(
            seconds: Int64(sb.st_atim.tv_sec),
            nanoseconds: Int32(sb.st_atim.tv_nsec)
        )
        self.modificationTime = Kernel.Time(
            seconds: Int64(sb.st_mtim.tv_sec),
            nanoseconds: Int32(sb.st_mtim.tv_nsec)
        )
        self.changeTime = Kernel.Time(
            seconds: Int64(sb.st_ctim.tv_sec),
            nanoseconds: Int32(sb.st_ctim.tv_nsec)
        )
        #endif
    }
}

extension Kernel.Stat.Kind {
    /// Creates a file kind from POSIX mode bits.
    @inlinable
    init(posixMode mode: mode_t) {
        switch mode & S_IFMT {
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

// MARK: - Statfs Conversion

extension Kernel.Statfs {
    /// Creates a Statfs from a POSIX statfs structure.
    @inlinable
    init(posix buf: PlatformStatfs) {
        #if canImport(Darwin)
        // Darwin uses f_type for filesystem type
        self.type = UInt64(buf.f_type)
        self.blockSize = UInt64(buf.f_bsize)
        self.blocks = UInt64(buf.f_blocks)
        self.freeBlocks = UInt64(buf.f_bfree)
        self.availableBlocks = UInt64(buf.f_bavail)
        self.files = UInt64(buf.f_files)
        self.freeFiles = UInt64(buf.f_ffree)
        // Darwin fsid is a struct with val[2] (signed int32_t)
        // Use bitPattern to preserve bits for signed values
        self.fsid = UInt64(bitPattern: Int64(buf.f_fsid.val.0)) | (UInt64(bitPattern: Int64(buf.f_fsid.val.1)) << 32)
        // Darwin doesn't have f_namelen in statfs, use NAME_MAX
        // Most Darwin filesystems support at least NAME_MAX (255) characters
        self.nameMax = UInt64(NAME_MAX)
        // Darwin has f_fstypename which gives the filesystem type name
        self.fsTypeName = withUnsafeBytes(of: buf.f_fstypename) { ptr in
            // f_fstypename is a tuple of CChars, convert to String
            let cString = ptr.bindMemory(to: CChar.self)
            return String(cString: cString.baseAddress!)
        }
        #else
        // Linux (Glibc/Musl) uses f_type for filesystem type
        self.type = UInt64(buf.f_type)
        self.blockSize = UInt64(buf.f_bsize)
        self.blocks = UInt64(buf.f_blocks)
        self.freeBlocks = UInt64(buf.f_bfree)
        self.availableBlocks = UInt64(buf.f_bavail)
        self.files = UInt64(buf.f_files)
        self.freeFiles = UInt64(buf.f_ffree)
        // Linux fsid is a struct with __val[2] (signed int)
        // Use bitPattern to preserve bits for signed values
        self.fsid = UInt64(bitPattern: Int64(buf.f_fsid.__val.0)) | (UInt64(bitPattern: Int64(buf.f_fsid.__val.1)) << 32)
        self.nameMax = UInt64(buf.f_namelen)
        // Linux statfs doesn't have a filesystem name field
        self.fsTypeName = nil
        #endif
    }
}

#endif

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

// MARK: - C Helper Functions
//
// These helpers wrap platform-specific syscall functions to avoid name collisions
// and provide a consistent interface. All are @usableFromInline internal.

// MARK: - POSIX Helpers

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    // Type Aliases

    @usableFromInline
    internal typealias PlatformStat = stat

    #if canImport(Darwin)
        @usableFromInline
        internal typealias PlatformStatfs = Darwin.statfs
    #else
        @usableFromInline
        internal typealias PlatformStatfs = statfs
    #endif

    // File Operations

    @usableFromInline
    internal func _cOpen(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
        #if canImport(Darwin)
            Darwin.open(path, flags, mode)
        #elseif canImport(Glibc)
            Glibc.open(path, flags, mode)
        #elseif canImport(Musl)
            Musl.open(path, flags, mode)
        #endif
    }

    @usableFromInline
    internal func _cOpen(_ path: UnsafePointer<CChar>, _ flags: Int32) -> Int32 {
        #if canImport(Darwin)
            Darwin.open(path, flags)
        #elseif canImport(Glibc)
            Glibc.open(path, flags)
        #elseif canImport(Musl)
            Musl.open(path, flags)
        #endif
    }

    @usableFromInline
    internal func _cClose(_ fd: Int32) -> Int32 {
        #if canImport(Darwin)
            Darwin.close(fd)
        #elseif canImport(Glibc)
            Glibc.close(fd)
        #elseif canImport(Musl)
            Musl.close(fd)
        #endif
    }

    @usableFromInline
    internal func _cRead(_ fd: Int32, _ buf: UnsafeMutableRawPointer, _ nbyte: Int) -> Int {
        #if canImport(Darwin)
            Darwin.read(fd, buf, nbyte)
        #elseif canImport(Glibc)
            Glibc.read(fd, buf, nbyte)
        #elseif canImport(Musl)
            Musl.read(fd, buf, nbyte)
        #endif
    }

    @usableFromInline
    internal func _cWrite(_ fd: Int32, _ buf: UnsafeRawPointer, _ nbyte: Int) -> Int {
        #if canImport(Darwin)
            Darwin.write(fd, buf, nbyte)
        #elseif canImport(Glibc)
            Glibc.write(fd, buf, nbyte)
        #elseif canImport(Musl)
            Musl.write(fd, buf, nbyte)
        #endif
    }

    @usableFromInline
    internal func _cPread(_ fd: Int32, _ buf: UnsafeMutableRawPointer, _ nbyte: Int, _ offset: off_t) -> Int {
        #if canImport(Darwin)
            Darwin.pread(fd, buf, nbyte, offset)
        #elseif canImport(Glibc)
            Glibc.pread(fd, buf, nbyte, offset)
        #elseif canImport(Musl)
            Musl.pread(fd, buf, nbyte, offset)
        #endif
    }

    @usableFromInline
    internal func _cPwrite(_ fd: Int32, _ buf: UnsafeRawPointer, _ nbyte: Int, _ offset: off_t) -> Int {
        #if canImport(Darwin)
            Darwin.pwrite(fd, buf, nbyte, offset)
        #elseif canImport(Glibc)
            Glibc.pwrite(fd, buf, nbyte, offset)
        #elseif canImport(Musl)
            Musl.pwrite(fd, buf, nbyte, offset)
        #endif
    }

    // Stat Operations

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
        statfs(path, &buf)
    }

    @usableFromInline
    internal func _cFstatfs(_ fd: Int32, _ buf: inout PlatformStatfs) -> Int32 {
        fstatfs(fd, &buf)
    }

    // Permissions and Ownership

    @usableFromInline
    internal func _cChmod(_ path: UnsafePointer<CChar>, _ mode: mode_t) -> Int32 {
        chmod(path, mode)
    }

    @usableFromInline
    internal func _cChown(_ path: UnsafePointer<CChar>, _ uid: uid_t, _ gid: gid_t) -> Int32 {
        chown(path, uid, gid)
    }

    // Links

    @usableFromInline
    internal func _cLink(_ existing: UnsafePointer<CChar>, _ new: UnsafePointer<CChar>) -> Int32 {
        link(existing, new)
    }

    @usableFromInline
    internal func _cSymlink(_ target: UnsafePointer<CChar>, _ link: UnsafePointer<CChar>) -> Int32 {
        symlink(target, link)
    }

    @usableFromInline
    internal func _cReadlink(_ path: UnsafePointer<CChar>, _ buf: UnsafeMutablePointer<CChar>, _ bufsize: Int) -> Int {
        readlink(path, buf, bufsize)
    }

    @usableFromInline
    internal func _cUnlink(_ path: UnsafePointer<CChar>) -> Int32 {
        unlink(path)
    }

    // Linux-specific syscalls

    #if os(Linux)

    @usableFromInline
    internal func _cCopyFileRange(
        _ fdIn: Int32, _ offIn: UnsafeMutablePointer<off_t>?,
        _ fdOut: Int32, _ offOut: UnsafeMutablePointer<off_t>?,
        _ len: Int, _ flags: UInt32
    ) -> Int {
        swift_copy_file_range(fdIn, offIn, fdOut, offOut, len, flags)
    }

    @usableFromInline
    internal func _cFiclone(_ destFd: Int32, _ srcFd: Int32) -> Int32 {
        swift_ficlone(destFd, srcFd)
    }

    #endif

#endif

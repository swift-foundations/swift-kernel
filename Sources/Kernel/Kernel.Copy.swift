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

// MARK: - Copy Error Type

extension Kernel {
    /// File copy operations.
    public enum Copy: Sendable {
        public enum Error: Swift.Error, Sendable {
            case handle(Kernel.Handle.Error)
            case io(Kernel.IO.Error)
            case space(Kernel.Space.Error)
            case permission(Kernel.Permission.Error)
            case platform(Kernel.Platform.Error)
            /// Operation not supported (e.g., cross-filesystem copy_file_range).
            case unsupported
        }
    }
}

extension Kernel.Copy.Error: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.handle(let l), .handle(let r)): return l == r
        case (.io(let l), .io(let r)): return l == r
        case (.space(let l), .space(let r)): return l == r
        case (.permission(let l), .permission(let r)): return l == r
        case (.platform(let l), .platform(let r)): return l == r
        case (.unsupported, .unsupported): return true
        default: return false
        }
    }
}

extension Kernel.Copy.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let e): return "handle: \(e)"
        case .io(let e): return "io: \(e)"
        case .space(let e): return "space: \(e)"
        case .permission(let e): return "permission: \(e)"
        case .platform(let e): return "\(e)"
        case .unsupported: return "operation not supported"
        }
    }
}

// MARK: - Linux Implementation

#if os(Linux)

#if canImport(Glibc)
public import Glibc
public import CLinuxShim
#elseif canImport(Musl)
public import Musl
#endif

extension Kernel.Copy.Error {
    @inlinable
    init(errno: Errno) {
        switch errno {
        case .crossDeviceLink, .invalidArgument:
            // EXDEV: cross-filesystem, EINVAL: unsupported
            self = .unsupported
        default:
            if let e = Kernel.Handle.Error(errno: errno) {
                self = .handle(e)
                return
            }
            if let e = Kernel.IO.Error(errno: errno) {
                self = .io(e)
                return
            }
            if let e = Kernel.Space.Error(errno: errno) {
                self = .space(e)
                return
            }
            if let e = Kernel.Permission.Error(errno: errno) {
                self = .permission(e)
                return
            }
            self = .platform(Kernel.Platform.Error(errno: errno))
        }
    }

    @inlinable
    static func current() -> Self {
        Self(errno: Errno(rawValue: errno))
    }
}

extension Kernel.Copy {
    /// Copies bytes between file descriptors using copy_file_range(2).
    ///
    /// This is a Linux-specific syscall that can perform efficient
    /// server-side copies on supported filesystems (e.g., NFS, Btrfs).
    ///
    /// - Parameters:
    ///   - source: Source file descriptor.
    ///   - sourceOffset: Offset in source file (updated on return). Pass nil to use current position.
    ///   - destination: Destination file descriptor.
    ///   - destOffset: Offset in destination file (updated on return). Pass nil to use current position.
    ///   - length: Maximum number of bytes to copy.
    /// - Returns: Number of bytes copied.
    /// - Throws: `Kernel.Copy.Error` on failure.
    @inlinable
    public static func copyFileRange(
        from source: Kernel.Descriptor,
        sourceOffset: inout Int64,
        to destination: Kernel.Descriptor,
        destOffset: inout Int64,
        length: Int
    ) throws(Error) -> Int {
        guard source.isValid else { throw .handle(.invalid) }
        guard destination.isValid else { throw .handle(.invalid) }

        var srcOff = off_t(sourceOffset)
        var dstOff = off_t(destOffset)

        let result = _cCopyFileRange(
            source.rawValue, &srcOff,
            destination.rawValue, &dstOff,
            length, 0
        )

        guard result >= 0 else {
            throw .current()
        }

        sourceOffset = Int64(srcOff)
        destOffset = Int64(dstOff)
        return result
    }

    /// Clones a file using FICLONE ioctl.
    ///
    /// Creates a copy-on-write clone of the source file. Both files
    /// share the same data blocks until one is modified.
    ///
    /// Only supported on filesystems with reflink capability (Btrfs, XFS with reflink).
    ///
    /// - Parameters:
    ///   - source: Source file descriptor.
    ///   - destination: Destination file descriptor (must be empty).
    /// - Throws: `Kernel.Copy.Error` on failure.
    @inlinable
    public static func clone(
        from source: Kernel.Descriptor,
        to destination: Kernel.Descriptor
    ) throws(Error) {
        guard source.isValid else { throw .handle(.invalid) }
        guard destination.isValid else { throw .handle(.invalid) }

        let result = _cFiclone(destination.rawValue, source.rawValue)
        guard result == 0 else {
            throw .current()
        }
    }
}

#endif

// MARK: - Darwin Implementation

#if canImport(Darwin)

public import Darwin

extension Kernel.Copy.Error {
    @inlinable
    init(errno: Errno) {
        if let e = Kernel.Handle.Error(errno: errno) {
            self = .handle(e)
            return
        }
        if let e = Kernel.IO.Error(errno: errno) {
            self = .io(e)
            return
        }
        if let e = Kernel.Space.Error(errno: errno) {
            self = .space(e)
            return
        }
        if let e = Kernel.Permission.Error(errno: errno) {
            self = .permission(e)
            return
        }
        self = .platform(Kernel.Platform.Error(errno: errno))
    }

    @inlinable
    static func current() -> Self {
        Self(errno: Errno(rawValue: errno))
    }
}

extension Kernel.Copy {
    /// Clones a file using clonefile(2).
    ///
    /// Creates a copy-on-write clone of the source file on APFS.
    ///
    /// - Parameters:
    ///   - sourcePath: Path to source file.
    ///   - destPath: Path for destination file (must not exist).
    /// - Throws: `Kernel.Copy.Error` on failure.
    @inlinable
    public static func clonefile(
        from sourcePath: String,
        to destPath: String
    ) throws(Error) {
        let result = sourcePath.withCString { src in
            destPath.withCString { dst in
                Darwin.clonefile(src, dst, 0)
            }
        }
        guard result == 0 else {
            throw .current()
        }
    }
}

#endif

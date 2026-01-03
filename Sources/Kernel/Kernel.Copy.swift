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

// MARK: - Copy Error Type

extension Kernel {
    /// File copy operations.
    public enum Copy: Sendable {
        /// Errors from copy operations.
        ///
        /// Each case represents a specific failure mode of `copy_file_range`,
        /// `clone` (FICLONE), or `clonefile`.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Invalid file descriptor.
            /// - POSIX: `EBADF`
            case invalidDescriptor

            /// Cross-device copy not supported.
            /// - POSIX: `EXDEV`
            ///
            /// The source and destination are on different filesystems.
            case crossDevice

            /// Operation not supported.
            /// - POSIX: `EINVAL`, `ENOTSUP`, `EOPNOTSUPP`
            ///
            /// The filesystem or file type doesn't support this operation.
            case unsupported

            /// No space left on device.
            /// - POSIX: `ENOSPC`
            case noSpace

            /// Physical I/O error.
            /// - POSIX: `EIO`
            case io

            /// Permission denied.
            /// - POSIX: `EACCES`, `EPERM`
            case permissionDenied
        }
    }
}

extension Kernel.Copy.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidDescriptor: return "invalid file descriptor"
        case .crossDevice: return "cross-device copy not supported"
        case .unsupported: return "operation not supported"
        case .noSpace: return "no space left on device"
        case .io: return "I/O error"
        case .permissionDenied: return "permission denied"
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

    extension Kernel.Copy {
        /// Range-based copy operations using copy_file_range(2).
        public enum Range {
            /// Copies bytes between file descriptors using copy_file_range(2).
            ///
            /// This is a Linux-specific syscall that can perform efficient
            /// server-side copies on supported filesystems (e.g., NFS, Btrfs).
            ///
            /// - Parameters:
            ///   - source: Source file descriptor.
            ///   - sourceOffset: Offset in source file (updated on return).
            ///   - destination: Destination file descriptor.
            ///   - destOffset: Offset in destination file (updated on return).
            ///   - length: Maximum number of bytes to copy.
            /// - Returns: Number of bytes copied.
            /// - Throws: `Kernel.Copy.Error` on failure.
            @inlinable
            public static func copy(
                from source: Kernel.Descriptor,
                sourceOffset: inout Int64,
                to destination: Kernel.Descriptor,
                destOffset: inout Int64,
                length: Int
            ) throws(Kernel.Copy.Error) -> Int {
                guard source.isValid else { throw .invalidDescriptor }
                guard destination.isValid else { throw .invalidDescriptor }

                var srcOff = off_t(sourceOffset)
                var dstOff = off_t(destOffset)

                let result = _cCopyFileRange(
                    source.rawValue,
                    &srcOff,
                    destination.rawValue,
                    &dstOff,
                    length,
                    0
                )

                guard result >= 0 else {
                    throw Kernel.Copy.Error(posix: errno)
                }

                sourceOffset = Int64(srcOff)
                destOffset = Int64(dstOff)
                return result
            }
        }

        /// Clone operations using FICLONE ioctl.
        public enum Clone {
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
            public static func perform(
                from source: Kernel.Descriptor,
                to destination: Kernel.Descriptor
            ) throws(Kernel.Copy.Error) {
                guard source.isValid else { throw .invalidDescriptor }
                guard destination.isValid else { throw .invalidDescriptor }

                let result = _cFiclone(destination.rawValue, source.rawValue)
                guard result == 0 else {
                    throw Kernel.Copy.Error(posix: errno)
                }
            }
        }
    }

    extension Kernel.Copy.Error {
        @usableFromInline
        init(posix code: Int32) {
            switch code {
            case EBADF:
                self = .invalidDescriptor
            case EXDEV:
                self = .crossDevice
            case EINVAL, ENOTSUP, EOPNOTSUPP:
                self = .unsupported
            case ENOSPC:
                self = .noSpace
            case EIO:
                self = .io
            case EACCES, EPERM:
                self = .permissionDenied
            default:
                // Map unknown errors to unsupported as a fallback
                self = .unsupported
            }
        }
    }

#endif

// MARK: - Darwin Implementation

#if canImport(Darwin)

    public import Darwin

    extension Kernel.Copy {
        /// Clone operations using clonefile(2).
        public enum Clone {
            /// Clones a file using clonefile(2).
            ///
            /// Creates a copy-on-write clone of the source file on APFS.
            ///
            /// - Parameters:
            ///   - sourcePath: Path to source file.
            ///   - destPath: Path for destination file (must not exist).
            /// - Throws: `Kernel.Copy.Error` on failure.
            @inlinable
            public static func file(
                from sourcePath: String,
                to destPath: String
            ) throws(Kernel.Copy.Error) {
                let result = sourcePath.withCString { src in
                    destPath.withCString { dst in
                        Darwin.clonefile(src, dst, 0)
                    }
                }
                guard result == 0 else {
                    throw Kernel.Copy.Error(posix: errno)
                }
            }
        }
    }

    extension Kernel.Copy.Error {
        @usableFromInline
        init(posix code: Int32) {
            switch code {
            case EBADF:
                self = .invalidDescriptor
            case EXDEV:
                self = .crossDevice
            case EINVAL, ENOTSUP, EOPNOTSUPP:
                self = .unsupported
            case ENOSPC:
                self = .noSpace
            case EIO:
                self = .io
            case EACCES, EPERM:
                self = .permissionDenied
            default:
                // Map unknown errors to unsupported as a fallback
                self = .unsupported
            }
        }
    }

#endif

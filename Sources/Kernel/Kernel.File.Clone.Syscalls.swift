// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//
//
// Platform-specific syscall wrappers for file cloning.
//

import SystemPackage

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

// MARK: - Capability Probing

extension Kernel.File.Clone.Capability {
    /// Probes whether the filesystem at the given path supports cloning.
    #if os(macOS)
        public static func probe(at path: String) throws(Kernel.File.Clone.SyscallError) -> Kernel.File.Clone.Capability {
            var statfsBuf = Darwin.statfs()
            let result = path.withCString { p in
                statfs(p, &statfsBuf)
            }

            guard result == 0 else {
                throw .posix(errno: errno, operation: .statfs)
            }

            // APFS filesystem type
            let fsType = withUnsafeBytes(of: statfsBuf.f_fstypename) { buf in
                String(cString: buf.bindMemory(to: CChar.self).baseAddress!)
            }

            // APFS supports cloning
            if fsType == "apfs" {
                return .reflink
            }

            return .none
        }
    #elseif os(Linux)
        public static func probe(at path: String) throws(Kernel.File.Clone.SyscallError) -> Kernel.File.Clone.Capability {
            let statfsBuf: Kernel.Statfs
            do {
                statfsBuf = try Kernel.Statfs.get(path: FilePath(path))
            } catch {
                throw .posix(errno: errno, operation: .statfs)
            }

            // Known filesystems that support FICLONE
            // Btrfs: 0x9123683E
            // XFS: 0x58465342 (with reflink enabled)
            // OCFS2: 0x7461636f
            let btrfsMagic: UInt64 = 0x9123_683E
            let xfsMagic: UInt64 = 0x5846_5342

            let fsMagic = statfsBuf.type
            if fsMagic == btrfsMagic || fsMagic == xfsMagic {
                return .reflink
            }

            return .none
        }
    #elseif os(Windows)
        /// Probes whether the filesystem at the given path supports cloning.
        ///
        /// On Windows, we conservatively return `.none` unless we can confirm ReFS.
        public static func probe(at path: String) throws(Kernel.File.Clone.SyscallError) -> Kernel.File.Clone.Capability {
            // Would need GetVolumeInformationW to check for ReFS
            // For now, conservatively return .none
            return .none
        }
    #endif
}

// MARK: - File Size Operations

extension Kernel.File.Clone {
    /// File metadata operations.
    public enum Metadata {
        /// Gets the size of a file.
        #if os(macOS)
            public static func size(at path: String) throws(Kernel.File.Clone.SyscallError) -> Int {
                var statBuf = Darwin.stat()
                let result = path.withCString { p in
                    stat(p, &statBuf)
                }

                guard result == 0 else {
                    throw .posix(errno: errno, operation: .stat)
                }

                return Int(statBuf.st_size)
            }
        #elseif os(Linux)
            public static func size(at path: String) throws(Kernel.File.Clone.SyscallError) -> Int {
                var statBuf = Glibc.stat()
                let result = path.withCString { p in
                    stat(p, &statBuf)
                }

                guard result == 0 else {
                    throw .posix(errno: errno, operation: .stat)
                }

                return Int(statBuf.st_size)
            }
        #endif

        #if os(Windows)
            public static func size(handle: HANDLE) throws(Kernel.File.Clone.SyscallError) -> UInt64 {
                var size: LARGE_INTEGER = LARGE_INTEGER()
                guard GetFileSizeEx(handle, &size) != 0 else {
                    throw .windows(code: GetLastError(), operation: .stat)
                }
                return UInt64(size.QuadPart)
            }
        #endif
    }
}

// MARK: - macOS Implementation

#if os(macOS)
    extension Kernel.File.Clone {
        /// macOS clonefile() operations.
        public enum Clonefile {
            /// Attempts to clone a file using clonefile().
            ///
            /// - Parameters:
            ///   - source: Source file path.
            ///   - destination: Destination file path.
            /// - Returns: `true` if cloned, `false` if not supported.
            /// - Throws: `Kernel.File.Clone.SyscallError` for other errors.
            public static func attempt(
                source: String,
                destination: String
            ) throws(Kernel.File.Clone.SyscallError) -> Bool {
                let result = source.withCString { src in
                    destination.withCString { dst in
                        clonefile(src, dst, 0)
                    }
                }

                if result == 0 {
                    return true
                }

                let err = errno
                // ENOTSUP means filesystem doesn't support cloning
                if err == ENOTSUP {
                    return false
                }

                throw .posix(errno: err, operation: .clonefile)
            }
        }

        /// macOS copyfile() operations.
        public enum Copyfile {
            /// Copies a file using copyfile() with COPYFILE_CLONE flag.
            ///
            /// This attempts CoW clone first, falls back to copy.
            public static func clone(
                source: String,
                destination: String
            ) throws(Kernel.File.Clone.SyscallError) {
                // Check if destination exists first (copyfile doesn't fail by default)
                var statBuf = Darwin.stat()
                let destExists = destination.withCString { stat($0, &statBuf) } == 0
                if destExists {
                    throw .posix(errno: EEXIST, operation: .copyfile)
                }

                let result = source.withCString { src in
                    destination.withCString { dst in
                        copyfile(src, dst, nil, copyfile_flags_t(COPYFILE_CLONE | COPYFILE_ALL))
                    }
                }

                guard result == 0 else {
                    throw .posix(errno: errno, operation: .copyfile)
                }
            }

            /// Copies a file using copyfile() without clone attempt.
            public static func data(
                source: String,
                destination: String
            ) throws(Kernel.File.Clone.SyscallError) {
                // Check if destination exists first (copyfile doesn't fail by default)
                var statBuf = Darwin.stat()
                let destExists = destination.withCString { stat($0, &statBuf) } == 0
                if destExists {
                    throw .posix(errno: EEXIST, operation: .copyfile)
                }

                let result = source.withCString { src in
                    destination.withCString { dst in
                        copyfile(src, dst, nil, copyfile_flags_t(COPYFILE_DATA))
                    }
                }

                guard result == 0 else {
                    throw .posix(errno: errno, operation: .copyfile)
                }
            }
        }
    }
#endif

// MARK: - Linux Implementation

#if os(Linux)
    // ioctl request code for FICLONE
    private let FICLONE: UInt = 0x4004_9409

    extension Kernel.File.Clone {
        /// Linux FICLONE operations.
        public enum Ficlone {
            /// Attempts to clone a file using ioctl(FICLONE).
            ///
            /// - Parameters:
            ///   - sourceFd: Source file descriptor.
            ///   - destFd: Destination file descriptor.
            /// - Returns: `true` if cloned, `false` if not supported.
            /// - Throws: `Kernel.File.Clone.SyscallError` for other errors.
            public static func attempt(
                sourceFd: Int32,
                destFd: Int32
            ) throws(Kernel.File.Clone.SyscallError) -> Bool {
                let result = ioctl(destFd, FICLONE, sourceFd)

                if result == 0 {
                    return true
                }

                let err = errno
                // EOPNOTSUPP/ENOTSUP means filesystem doesn't support cloning
                if err == EOPNOTSUPP || err == ENOTSUP || err == EINVAL || err == EXDEV {
                    return false
                }

                throw .posix(errno: err, operation: .ficlone)
            }
        }

        /// Linux copy_file_range operations.
        public enum CopyRange {
            /// Copies file data using copy_file_range().
            ///
            /// This may use server-side copy or reflink on supported filesystems.
            public static func copy(
                sourceFd: Int32,
                destFd: Int32,
                length: Int
            ) throws(Kernel.File.Clone.SyscallError) {
                var remaining = length
                var srcOffset: Int64 = 0
                var dstOffset: Int64 = 0

                while remaining > 0 {
                    let copied: Int
                    do {
                        copied = try Kernel.Copy.Range.copy(
                            from: Kernel.Descriptor(rawValue: sourceFd),
                            sourceOffset: &srcOffset,
                            to: Kernel.Descriptor(rawValue: destFd),
                            destOffset: &dstOffset,
                            length: remaining
                        )
                    } catch {
                        throw .posix(errno: errno, operation: .copyFileRange)
                    }

                    if copied == 0 {
                        break  // EOF
                    }

                    remaining -= copied
                }
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension Kernel.File.Clone {
        /// Windows extent duplication operations.
        public enum Extents {
            /// Attempts to duplicate file extents (ReFS block clone).
            ///
            /// This is highly constrained: same volume, ReFS only, specific alignment.
            /// Returns `false` if unsupported rather than erroring.
            public static func attempt(
                sourceHandle: HANDLE,
                destHandle: HANDLE,
                length: UInt64
            ) throws(Kernel.File.Clone.SyscallError) -> Bool {
                // ReFS block cloning requires FSCTL_DUPLICATE_EXTENTS_TO_FILE
                // This is complex and has many constraints, so we'll return false
                // for now and rely on CopyFile2 as the fallback.
                //
                // Full implementation would need:
                // - Verify both on same ReFS volume
                // - Align to cluster size
                // - Use DeviceIoControl with FSCTL_DUPLICATE_EXTENTS_TO_FILE
                return false
            }
        }

        /// Windows file copy operations.
        public enum Copy {
            /// Copies a file using CopyFileW.
            public static func file(
                source: String,
                destination: String
            ) throws(Kernel.File.Clone.SyscallError) {
                let result = source.withCString(encodedAs: UTF16.self) { src in
                    destination.withCString(encodedAs: UTF16.self) { dst in
                        CopyFileW(src, dst, true)  // true = fail if exists
                    }
                }

                guard result != 0 else {
                    throw .windows(code: GetLastError(), operation: .copy)
                }
            }
        }
    }
#endif

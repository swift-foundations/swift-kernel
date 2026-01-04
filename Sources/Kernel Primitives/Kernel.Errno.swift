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

#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif canImport(Musl)
    internal import Musl
#endif

extension Kernel {
    /// Platform errno constants for error matching.
    ///
    /// Prefer using `Kernel.Error` semantic types when possible.
    /// These raw values are for cases where platform error codes
    /// must be matched directly (e.g., converting driver errors).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// switch errno {
    /// case Kernel.Errno.noEntry:
    ///     // Handle ENOENT
    /// case Kernel.Errno.interrupted:
    ///     // Handle EINTR
    /// default:
    ///     break
    /// }
    /// ```
    public enum Errno: Sendable {
        #if !os(Windows)
            /// File or directory does not exist (ENOENT).
            public static var noEntry: Int32 { ENOENT }

            /// Permission denied (EACCES).
            public static var accessDenied: Int32 { EACCES }

            /// Operation not permitted (EPERM).
            public static var notPermitted: Int32 { EPERM }

            /// File or directory already exists (EEXIST).
            public static var exists: Int32 { EEXIST }

            /// Is a directory (EISDIR).
            public static var isDirectory: Int32 { EISDIR }

            /// Too many open files in process (EMFILE).
            public static var processLimit: Int32 { EMFILE }

            /// Too many open files in system (ENFILE).
            public static var systemLimit: Int32 { ENFILE }

            /// Invalid argument (EINVAL).
            public static var invalid: Int32 { EINVAL }

            /// Interrupted system call (EINTR).
            public static var interrupted: Int32 { EINTR }

            /// Resource temporarily unavailable / would block (EAGAIN).
            public static var wouldBlock: Int32 { EAGAIN }

            /// No such device (ENODEV).
            public static var noDevice: Int32 { ENODEV }

            /// Not a directory (ENOTDIR).
            public static var notDirectory: Int32 { ENOTDIR }

            /// Read-only file system (EROFS).
            public static var readOnlyFilesystem: Int32 { EROFS }

            /// No space left on device (ENOSPC).
            public static var noSpace: Int32 { ENOSPC }

            /// Bad file descriptor (EBADF).
            public static var badDescriptor: Int32 { EBADF }
        #endif
    }
}

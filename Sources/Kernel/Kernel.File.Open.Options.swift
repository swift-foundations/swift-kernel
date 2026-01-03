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

extension Kernel.File.Open {
    /// Options for opening files.
    ///
    /// These are portable flags that map to platform-specific values internally.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - Standard Options

extension Kernel.File.Open.Options {
    /// Create the file if it does not exist.
    ///
    /// - POSIX: `O_CREAT`
    /// - Windows: `CREATE_NEW` or `OPEN_ALWAYS` (combined with other flags)
    public static let create = Self(rawValue: 1 << 0)

    /// Truncate the file to zero length if it exists.
    ///
    /// - POSIX: `O_TRUNC`
    /// - Windows: `TRUNCATE_EXISTING` (combined with other flags)
    public static let truncate = Self(rawValue: 1 << 1)

    /// Writes append to the end of the file.
    ///
    /// - POSIX: `O_APPEND`
    /// - Windows: `FILE_APPEND_DATA` access mode
    public static let append = Self(rawValue: 1 << 2)

    /// Fail if the file already exists (requires `.create`).
    ///
    /// - POSIX: `O_EXCL`
    /// - Windows: `CREATE_NEW`
    public static let exclusive = Self(rawValue: 1 << 3)

    /// Request direct I/O (bypass page cache).
    ///
    /// - POSIX (Linux): `O_DIRECT`
    /// - Windows: `FILE_FLAG_NO_BUFFERING`
    ///
    /// - Note: This is a hint. The Kernel layer provides the flag but does
    ///   not validate alignment requirements. Higher layers (swift-io)
    ///   handle capability probing and alignment validation.
    public static let direct = Self(rawValue: 1 << 6)

    /// Do not follow symlinks when opening.
    ///
    /// - POSIX: `O_NOFOLLOW`
    /// - Windows: `FILE_FLAG_OPEN_REPARSE_POINT`
    ///
    /// On POSIX, this causes open() to fail with ELOOP if the path is a symlink.
    /// On Windows, this opens the reparse point itself rather than following it.
    public static let noFollow = Self(rawValue: 1 << 8)
}

// MARK: - Internal Constants

extension Kernel.File.Open.Options {
    // Internal bit positions for behavior options
    @usableFromInline
    internal static let execClose = Self(rawValue: 1 << 4)
    @usableFromInline
    internal static let blockingDisabled = Self(rawValue: 1 << 5)
    @usableFromInline
    internal static let cacheDisabled = Self(rawValue: 1 << 7)
}

// MARK: - POSIX Conversion

#if !os(Windows)
    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        import Glibc
        import CLinuxShim
    #elseif canImport(Musl)
        internal import Musl
    #endif

    extension Kernel.File.Open.Options {
        /// Converts the options to POSIX open flags.
        @usableFromInline
        internal var posixFlags: Int32 {
            var flags: Int32 = 0

            if contains(.create) {
                flags |= O_CREAT
            }
            if contains(.truncate) {
                flags |= O_TRUNC
            }
            if contains(.append) {
                flags |= O_APPEND
            }
            if contains(.exclusive) {
                flags |= O_EXCL
            }
            if contains(.execClose) {
                flags |= O_CLOEXEC
            }
            if contains(.blockingDisabled) {
                flags |= O_NONBLOCK
            }
            #if os(Linux)
                if contains(.direct) {
                    flags |= O_DIRECT
                }
            #endif
            if contains(.noFollow) {
                flags |= O_NOFOLLOW
            }

            return flags
        }
    }
#endif

// MARK: - Windows Conversion

#if os(Windows)
    public import WinSDK

    extension Kernel.File.Open.Options {
        /// Converts the options to Windows creation disposition.
        @usableFromInline
        internal var windowsCreationDisposition: DWORD {
            let hasCreate = contains(.create)
            let hasExclusive = contains(.exclusive)
            let hasTruncate = contains(.truncate)

            if hasCreate && hasExclusive {
                return DWORD(CREATE_NEW)
            } else if hasCreate && hasTruncate {
                return DWORD(CREATE_ALWAYS)
            } else if hasCreate {
                return DWORD(OPEN_ALWAYS)
            } else if hasTruncate {
                return DWORD(TRUNCATE_EXISTING)
            } else {
                return DWORD(OPEN_EXISTING)
            }
        }

        /// Converts the options to Windows flags and attributes.
        @usableFromInline
        internal var windowsFlagsAndAttributes: DWORD {
            var flags: DWORD = DWORD(FILE_ATTRIBUTE_NORMAL)

            if contains(.direct) {
                flags |= DWORD(FILE_FLAG_NO_BUFFERING)
            }
            if contains(.noFollow) {
                flags |= DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
            }

            return flags
        }

        /// Windows share mode for open operations.
        ///
        /// Default: `FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE`
        ///
        /// This is a documented stability guarantee matching common POSIX expectations.
        @usableFromInline
        internal static var windowsShareMode: DWORD {
            return DWORD(FILE_SHARE_READ) | DWORD(FILE_SHARE_WRITE) | DWORD(FILE_SHARE_DELETE)
        }
    }
#endif

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
    /// Types and options for opening files.
    public struct Open {
        /// File access mode as an OptionSet.
        ///
        /// Use `[.read]`, `[.write]`, or `[.read, .write]` for access modes.
        public struct Mode: OptionSet, Sendable {
            public let rawValue: UInt8

            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }

            /// Open for reading.
            public static let read = Mode(rawValue: 1 << 0)

            /// Open for writing.
            public static let write = Mode(rawValue: 1 << 1)
        }

        /// Options for opening files.
        ///
        /// These are portable flags that map to platform-specific values internally.
        public struct Options: OptionSet, Sendable {
            public let rawValue: UInt32

            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            // MARK: - Standard Options

            /// Create the file if it does not exist.
            ///
            /// - POSIX: `O_CREAT`
            /// - Windows: `CREATE_NEW` or `OPEN_ALWAYS` (combined with other flags)
            public static let create = Options(rawValue: 1 << 0)

            /// Truncate the file to zero length if it exists.
            ///
            /// - POSIX: `O_TRUNC`
            /// - Windows: `TRUNCATE_EXISTING` (combined with other flags)
            public static let truncate = Options(rawValue: 1 << 1)

            /// Writes append to the end of the file.
            ///
            /// - POSIX: `O_APPEND`
            /// - Windows: `FILE_APPEND_DATA` access mode
            public static let append = Options(rawValue: 1 << 2)

            /// Fail if the file already exists (requires `.create`).
            ///
            /// - POSIX: `O_EXCL`
            /// - Windows: `CREATE_NEW`
            public static let exclusive = Options(rawValue: 1 << 3)

            // MARK: - Direct I/O Hints

            /// Request direct I/O (bypass page cache).
            ///
            /// - POSIX (Linux): `O_DIRECT`
            /// - Windows: `FILE_FLAG_NO_BUFFERING`
            ///
            /// - Note: This is a hint. The Kernel layer provides the flag but does
            ///   not validate alignment requirements. Higher layers (swift-io)
            ///   handle capability probing and alignment validation.
            public static let direct = Options(rawValue: 1 << 6)

            // MARK: - Symlink Handling

            /// Do not follow symlinks when opening.
            ///
            /// - POSIX: `O_NOFOLLOW`
            /// - Windows: `FILE_FLAG_OPEN_REPARSE_POINT`
            ///
            /// On POSIX, this causes open() to fail with ELOOP if the path is a symlink.
            /// On Windows, this opens the reparse point itself rather than following it.
            public static let noFollow = Options(rawValue: 1 << 8)
        }

        /// Exec behavior options.
        public enum Exec: Sendable {
            /// Close descriptor options.
            public enum Close: Sendable {
                /// Close the file descriptor on exec.
                ///
                /// - POSIX: `O_CLOEXEC`
                /// - Windows: Non-inheritable handle (default behavior)
                case enabled
            }
        }

        /// Blocking behavior options.
        public enum Blocking: Sendable {
            /// Disable blocking I/O.
            ///
            /// - POSIX: `O_NONBLOCK`
            /// - Windows: Requires async I/O with OVERLAPPED structures
            ///
            /// - Note: This flag is primarily for POSIX. On Windows, non-blocking
            ///   semantics require a different I/O model (IOCP).
            case disabled
        }

        /// Cache behavior options.
        public enum Cache: Sendable {
            /// Disable caching (macOS only).
            ///
            /// - macOS: `F_NOCACHE` via `fcntl` after open
            /// - Other platforms: Ignored
            ///
            /// - Note: This is a weaker hint than `.direct` on macOS.
            case disabled
        }
    }
}

// MARK: - Options Internal Constants

extension Kernel.File.Open.Options {
    // Internal bit positions for behavior options
    @usableFromInline
    internal static let execClose = Self(rawValue: 1 << 4)
    @usableFromInline
    internal static let blockingDisabled = Self(rawValue: 1 << 5)
    @usableFromInline
    internal static let cacheDisabled = Self(rawValue: 1 << 7)
}

// MARK: - Internal Flag Conversion

#if !os(Windows)
    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        internal import Musl
    #endif

    extension Kernel.File.Open.Mode {
        /// Converts the mode to POSIX open flags.
        @usableFromInline
        internal var posixFlags: Int32 {
            let hasRead = contains(.read)
            let hasWrite = contains(.write)

            if hasRead && hasWrite {
                return O_RDWR
            } else if hasWrite {
                return O_WRONLY
            } else {
                return O_RDONLY
            }
        }
    }

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

#if os(Windows)
    public import WinSDK

    extension Kernel.File.Open.Mode {
        /// Converts the mode to Windows desired access flags.
        @usableFromInline
        internal func windowsDesiredAccess(options: Kernel.File.Open.Options) -> DWORD {
            let hasRead = contains(.read)
            let hasWrite = contains(.write)
            let hasAppend = options.contains(.append)

            var access: DWORD = 0

            if hasRead {
                access |= GENERIC_READ
            }
            if hasWrite {
                if hasAppend {
                    // Append mode: use FILE_APPEND_DATA instead of GENERIC_WRITE
                    // This ensures all writes go to the end of the file
                    access |= FILE_APPEND_DATA
                } else {
                    access |= GENERIC_WRITE
                }
            }

            // If no mode specified, default to read
            if access == 0 {
                access = GENERIC_READ
            }

            return access
        }
    }

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
            var flags: DWORD = FILE_ATTRIBUTE_NORMAL

            if contains(.direct) {
                flags |= FILE_FLAG_NO_BUFFERING
            }
            if contains(.noFollow) {
                flags |= FILE_FLAG_OPEN_REPARSE_POINT
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
            return FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
        }
    }
#endif

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
    /// File access mode as an OptionSet.
    ///
    /// Use `[.read]`, `[.write]`, or `[.read, .write]` for access modes.
    public struct Mode: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - Static Members

extension Kernel.File.Open.Mode {
    /// Open for reading.
    public static let read = Self(rawValue: 1 << 0)

    /// Open for writing.
    public static let write = Self(rawValue: 1 << 1)
}

// MARK: - POSIX Conversion

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
#endif

// MARK: - Windows Conversion

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
                access |= DWORD(GENERIC_READ)
            }
            if hasWrite {
                if hasAppend {
                    // Append mode: use FILE_APPEND_DATA instead of GENERIC_WRITE
                    // This ensures all writes go to the end of the file
                    access |= DWORD(FILE_APPEND_DATA)
                } else {
                    access |= DWORD(GENERIC_WRITE)
                }
            }

            // If no mode specified, default to read
            if access == 0 {
                access = DWORD(GENERIC_READ)
            }

            return access
        }
    }
#endif

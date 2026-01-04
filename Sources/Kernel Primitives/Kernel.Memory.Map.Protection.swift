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

extension Kernel.Memory.Map {
    /// Memory protection flags.
    ///
    /// This is a custom value type (not OptionSet) to stay faithful
    /// to the OS model and avoid policy creep.
    public struct Protection: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// No access permitted.
        public static let none = Protection(rawValue: 0)

        /// Combines multiple protection flags.
        @inlinable
        public static func | (lhs: Protection, rhs: Protection) -> Protection {
            Protection(rawValue: lhs.rawValue | rhs.rawValue)
        }

        /// Checks if this contains another protection flag.
        @inlinable
        public func contains(_ other: Protection) -> Bool {
            (rawValue & other.rawValue) == other.rawValue
        }
    }
}

// MARK: - POSIX Constants

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Memory.Map.Protection {
        /// Pages may be read.
        public static let read = Self(rawValue: PROT_READ)

        /// Pages may be written.
        public static let write = Self(rawValue: PROT_WRITE)

        /// Pages may be executed.
        public static let execute = Self(rawValue: PROT_EXEC)

        /// Read and write access.
        public static let readWrite = read | write
    }

#endif

// MARK: - Windows Constants

#if os(Windows)
    public import WinSDK

    extension Kernel.Memory.Map.Protection {
        /// Pages may be read.
        public static let read = Self(rawValue: 1)

        /// Pages may be written.
        public static let write = Self(rawValue: 2)

        /// Pages may be executed.
        public static let execute = Self(rawValue: 4)

        /// Read and write access.
        public static let readWrite = read | write

        /// Converts to Windows page protection constant.
        var windowsPageProtection: DWORD {
            let r = contains(.read)
            let w = contains(.write)
            let x = contains(.execute)

            switch (r, w, x) {
            case (false, false, false): return DWORD(PAGE_NOACCESS)
            case (true, false, false): return DWORD(PAGE_READONLY)
            case (true, true, false): return DWORD(PAGE_READWRITE)
            case (true, false, true): return DWORD(PAGE_EXECUTE_READ)
            case (true, true, true): return DWORD(PAGE_EXECUTE_READWRITE)
            case (false, false, true): return DWORD(PAGE_EXECUTE)
            case (false, true, false): return DWORD(PAGE_READWRITE)
            case (false, true, true): return DWORD(PAGE_EXECUTE_READWRITE)
            }
        }

        /// Converts to Windows file map access flags.
        var windowsFileMapAccess: DWORD {
            var access: DWORD = 0
            if contains(.read) { access |= DWORD(FILE_MAP_READ) }
            if contains(.write) { access |= DWORD(FILE_MAP_WRITE) }
            if contains(.execute) { access |= DWORD(FILE_MAP_EXECUTE) }
            return access
        }
    }

#endif

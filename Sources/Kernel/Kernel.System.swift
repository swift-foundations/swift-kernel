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

extension Kernel {
    /// System information queries.
    public enum System {}
}

// MARK: - Alignment Helpers

extension Kernel.System {
    /// Rounds a value down to the nearest multiple of alignment.
    ///
    /// - Parameters:
    ///   - value: The value to align.
    ///   - alignment: The alignment boundary (must be a power of 2).
    /// - Returns: The largest multiple of `alignment` that is ≤ `value`.
    ///
    /// - Precondition: `alignment` must be a power of 2.
    @inlinable
    public static func alignDown(_ value: Int, to alignment: Int) -> Int {
        value & ~(alignment - 1)
    }

    /// Rounds a value up to the nearest multiple of alignment.
    ///
    /// - Parameters:
    ///   - value: The value to align.
    ///   - alignment: The alignment boundary (must be a power of 2).
    /// - Returns: The smallest multiple of `alignment` that is ≥ `value`.
    ///
    /// - Precondition: `alignment` must be a power of 2.
    @inlinable
    public static func alignUp(_ value: Int, to alignment: Int) -> Int {
        (value + alignment - 1) & ~(alignment - 1)
    }
}

#if !os(Windows)
    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        internal import CLinuxShim
    #elseif canImport(Musl)
        internal import Musl
    #endif

    extension Kernel.System {
        /// Memory page size in bytes.
        ///
        /// This is the fundamental unit of memory management.
        /// Typically 4096 bytes on most systems, 16384 on Apple Silicon.
        public static var pageSize: Int {
            Int(sysconf(Int32(_SC_PAGESIZE)))
        }

        /// Allocation granularity in bytes.
        ///
        /// On POSIX systems, this equals `pageSize`.
        /// On Windows, this is typically 64KB (larger than page size).
        ///
        /// Use this for memory mapping offset alignment.
        public static var allocationGranularity: Int {
            pageSize
        }

        /// Sleeps for the specified number of nanoseconds.
        ///
        /// - Parameter nanoseconds: The number of nanoseconds to sleep.
        @inlinable
        public static func sleep(nanoseconds: UInt64) {
            _cNanosleep(Int(nanoseconds / 1_000_000_000), Int(nanoseconds % 1_000_000_000))
        }
    }
#endif

#if os(Windows)
    @preconcurrency internal import WinSDK

    // Cache the system info since it never changes at runtime.
    // Uses nonisolated(unsafe) because SYSTEM_INFO is not Sendable but is immutable after initialization.
    private nonisolated(unsafe) let cachedSystemInfo: SYSTEM_INFO = {
        var info = SYSTEM_INFO()
        GetSystemInfo(&info)
        return info
    }()

    extension Kernel.System {
        /// Memory page size in bytes.
        public static var pageSize: Int {
            Int(cachedSystemInfo.dwPageSize)
        }

        /// Allocation granularity in bytes.
        ///
        /// On Windows, this is typically 64KB and differs from page size.
        /// Memory mapping offsets must be aligned to this value.
        public static var allocationGranularity: Int {
            Int(cachedSystemInfo.dwAllocationGranularity)
        }

        /// Sleeps for the specified number of nanoseconds.
        ///
        /// - Parameter nanoseconds: The number of nanoseconds to sleep.
        /// - Note: Windows Sleep has millisecond granularity.
        public static func sleep(nanoseconds: UInt64) {
            let milliseconds = nanoseconds / 1_000_000
            Sleep(DWORD(min(milliseconds, UInt64(DWORD.max))))
        }
    }
#endif

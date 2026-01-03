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
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.System {
        /// Platform path length limit.
        ///
        /// Falls back to 4096 if the platform constant is undefined.
        /// Note: This is a conservative limit, not a universal truth.
        public static var pathMax: Int {
            #if canImport(Darwin)
                return Int(PATH_MAX)  // 1024
            #else
                return Int(PATH_MAX)  // Usually 4096
            #endif
        }

        /// Memory page size in bytes.
        ///
        /// This is the fundamental unit of memory management.
        /// Typically 4096 bytes on most systems, 16384 on Apple Silicon.
        public static var pageSize: Int {
            Int(sysconf(Int32(_SC_PAGESIZE)))
        }

        /// Number of active/online processors.
        ///
        /// Uses `sysconf(_SC_NPROCESSORS_ONLN)` to get the count of
        /// processors currently online (not just configured).
        ///
        /// Returns 1 as a fallback if the syscall fails.
        public static var processorCount: Int {
            let count = sysconf(Int32(_SC_NPROCESSORS_ONLN))
            return count > 0 ? Int(count) : 1
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
            var ts = timespec()
            ts.tv_sec = Int(nanoseconds / 1_000_000_000)
            ts.tv_nsec = Int(nanoseconds % 1_000_000_000)
            nanosleep(&ts, nil)
        }
    }
#endif

#if os(Windows)
    @preconcurrency internal import WinSDK

    // PATTERN EXCEPTION: Global immutable cache (Rule 6.6)
    //
    // Justification: This is an immutable cache of system configuration that:
    // - Never changes at runtime (hardware properties)
    // - Is initialized exactly once on first access
    // - Has no observable side effects
    // - Cannot be testably injected (GetSystemInfo is a syscall)
    //
    // Uses nonisolated(unsafe) because SYSTEM_INFO is not Sendable but is
    // immutable after initialization. The value is a `let` constant.
    private nonisolated(unsafe) let cachedSystemInfo: SYSTEM_INFO = {
        var info = SYSTEM_INFO()
        GetSystemInfo(&info)
        return info
    }()

    extension Kernel.System {
        /// Platform path length limit.
        ///
        /// Note: This is a conservative limit. Extended-length paths
        /// on Windows can exceed MAX_PATH using \\?\ prefix.
        public static var pathMax: Int {
            Int(MAX_PATH)  // 260
        }

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

        /// Number of active processors.
        ///
        /// Uses the cached `SYSTEM_INFO` from `GetSystemInfo`.
        public static var processorCount: Int {
            Int(cachedSystemInfo.dwNumberOfProcessors)
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

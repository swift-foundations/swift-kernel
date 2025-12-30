//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

extension Kernel {
    /// System information queries.
    public enum System {}
}

#if !os(Windows)
#if canImport(Darwin)
internal import Darwin
#elseif canImport(Glibc)
internal import Glibc
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
}
#endif

#if os(Windows)
internal import WinSDK

// Cache the system info since it never changes at runtime
private let cachedSystemInfo: SYSTEM_INFO = {
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
}
#endif

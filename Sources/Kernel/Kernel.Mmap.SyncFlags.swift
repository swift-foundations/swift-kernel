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

extension Kernel.Mmap {
    /// Flags for msync operation.
    public struct SyncFlags: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Combines multiple flags.
        @inlinable
        public static func | (lhs: SyncFlags, rhs: SyncFlags) -> SyncFlags {
            SyncFlags(rawValue: lhs.rawValue | rhs.rawValue)
        }
    }
}

// MARK: - POSIX Constants

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.Mmap.SyncFlags {
        /// Perform synchronous writes.
        public static let sync = Self(rawValue: MS_SYNC)

        /// Schedule writes but return immediately.
        public static let async = Self(rawValue: MS_ASYNC)

        /// Invalidate cached data.
        public static let invalidate = Self(rawValue: MS_INVALIDATE)
    }

#endif

// MARK: - Windows Constants

#if os(Windows)

    extension Kernel.Mmap.SyncFlags {
        public static let sync = Self(rawValue: 1)
        public static let async = Self(rawValue: 2)
        public static let invalidate = Self(rawValue: 4)
    }

#endif

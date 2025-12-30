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
    /// Minimal time representation for file timestamps.
    ///
    /// Represents time as seconds and nanoseconds since the Unix epoch.
    /// This is the common denominator for POSIX `timespec` and Windows `FILETIME`.
    public struct Time: Sendable, Equatable, Hashable {
        /// Seconds since the Unix epoch (January 1, 1970 00:00:00 UTC).
        public let seconds: Int64

        /// Nanoseconds (0-999,999,999).
        public let nanoseconds: Int32

        /// Creates a time value.
        ///
        /// - Parameters:
        ///   - seconds: Seconds since the Unix epoch.
        ///   - nanoseconds: Nanoseconds (0-999,999,999).
        @inlinable
        public init(seconds: Int64, nanoseconds: Int32) {
            self.seconds = seconds
            self.nanoseconds = nanoseconds
        }

        /// Creates a time value from seconds only (no nanoseconds).
        @inlinable
        public init(seconds: Int64) {
            self.seconds = seconds
            self.nanoseconds = 0
        }
    }
}

// MARK: - Comparable

extension Kernel.Time: Comparable {
    @inlinable
    public static func < (lhs: Kernel.Time, rhs: Kernel.Time) -> Bool {
        if lhs.seconds != rhs.seconds {
            return lhs.seconds < rhs.seconds
        }
        return lhs.nanoseconds < rhs.nanoseconds
    }
}

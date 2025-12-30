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
    ///
    /// ## Converting to/from Other Time Types
    ///
    /// To convert to `StandardTime.Time`:
    /// ```swift
    /// import StandardTime
    ///
    /// extension StandardTime.Time {
    ///     init(_ kernelTime: Kernel.Time) {
    ///         self.init(
    ///             __unchecked: (),
    ///             secondsSinceEpoch: Int(kernelTime.seconds),
    ///             nanoseconds: Int(kernelTime.nanoseconds)
    ///         )
    ///     }
    /// }
    /// ```
    ///
    /// To convert from `StandardTime.Time`:
    /// ```swift
    /// extension Kernel.Time {
    ///     init(_ time: StandardTime.Time) {
    ///         self.init(
    ///             seconds: Int64(time.secondsSinceEpoch),
    ///             nanoseconds: Int32(time.nanoseconds)
    ///         )
    ///     }
    /// }
    /// ```
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

        /// Total time in nanoseconds since the Unix epoch.
        ///
        /// Useful for high-precision calculations and conversions.
        @inlinable
        public var totalNanoseconds: Int64 {
            seconds * 1_000_000_000 + Int64(nanoseconds)
        }

        /// Creates a time value from total nanoseconds since the Unix epoch.
        @inlinable
        public init(totalNanoseconds: Int64) {
            self.seconds = totalNanoseconds / 1_000_000_000
            self.nanoseconds = Int32(totalNanoseconds % 1_000_000_000)
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

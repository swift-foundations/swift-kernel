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

// MARK: - Duration Conversions

extension Kernel.Time {
    /// Converts a Duration to milliseconds for epoll/poll.
    ///
    /// - Parameter duration: The duration to convert, or `nil` for infinite wait.
    /// - Returns: Milliseconds as `CInt`. Returns `-1` for infinite (nil).
    ///   Saturates at `CInt.max` for very large durations.
    ///
    /// This is a pure conversion function with no policy decisions.
    /// The caller decides what "infinite" means and when to use it.
    @inlinable
    public static func milliseconds(from duration: Duration?) -> CInt {
        guard let duration else { return -1 }
        let (seconds, attoseconds) = duration.components
        let ms = seconds * 1000 + attoseconds / 1_000_000_000_000_000
        return ms > Int64(CInt.max) ? CInt.max : CInt(ms)
    }
}

#if !os(Windows)
    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Time {
        /// Converts a Duration to a POSIX timespec for kqueue/nanosleep.
        ///
        /// - Parameter duration: The duration to convert, or `nil` for infinite wait.
        /// - Returns: A `timespec` struct, or `nil` for infinite wait.
        ///
        /// This is a pure conversion function with no policy decisions.
        @inlinable
        public static func timespec(from duration: Duration?) -> timespec? {
            guard let duration else { return nil }
            let (seconds, attoseconds) = duration.components
            let nanoseconds = attoseconds / 1_000_000_000
            #if canImport(Darwin)
                return Darwin.timespec(tv_sec: Int(seconds), tv_nsec: Int(nanoseconds))
            #elseif canImport(Glibc)
                return Glibc.timespec(tv_sec: Int(seconds), tv_nsec: Int(nanoseconds))
            #elseif canImport(Musl)
                return Musl.timespec(tv_sec: Int(seconds), tv_nsec: Int(nanoseconds))
            #endif
        }
    }
#endif

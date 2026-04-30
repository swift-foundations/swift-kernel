// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// Time representation for kernel operations.
    ///
    /// Typealias to `Instant` from time-primitives. Represents time as
    /// seconds and nanoseconds since the Unix epoch.
    ///
    /// ## Platform Implementation
    ///
    /// Platform-specific time operations live at:
    /// - POSIX: `swift-iso-9945` (`ISO_9945.Kernel.Time`)
    /// - Windows: `swift-windows-standard` (`Windows.Kernel.Time`)
    public typealias Time = Instant
}

// MARK: - Kernel API Compatibility (package-internal)

extension Instant {
    /// Creates a time value (unchecked kernel API).
    ///
    /// - Parameters:
    ///   - seconds: Seconds since the Unix epoch.
    ///   - nanoseconds: Nanoseconds (0-999,999,999).
    @inlinable
    package init(seconds: Int64, nanoseconds: Int32) {
        self.init(
            __unchecked: (),
            secondsSinceUnixEpoch: seconds,
            nanosecondFraction: nanoseconds
        )
    }

    /// Creates a time value from seconds only (no nanoseconds).
    @inlinable
    package init(seconds: Int64) {
        self.init(seconds: seconds, nanoseconds: 0)
    }

    /// Seconds since the Unix epoch (alias for `secondsSinceUnixEpoch`).
    @inlinable
    package var seconds: Int64 { secondsSinceUnixEpoch }

    /// Nanoseconds (alias for `nanosecondFraction`).
    @inlinable
    package var nanoseconds: Int32 { nanosecondFraction }

    /// Total time in nanoseconds since the Unix epoch.
    @inlinable
    package var totalNanoseconds: Int64 {
        secondsSinceUnixEpoch * 1_000_000_000 + Int64(nanosecondFraction)
    }

    /// Creates a time value from total nanoseconds since the Unix epoch.
    @inlinable
    package init(totalNanoseconds: Int64) {
        self.init(
            seconds: totalNanoseconds / 1_000_000_000,
            nanoseconds: Int32(totalNanoseconds % 1_000_000_000)
        )
    }
}

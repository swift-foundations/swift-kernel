// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// Device ID.
    ///
    /// A type-safe wrapper for device identifiers. A device ID identifies
    /// the filesystem or device containing a file.
    ///
    /// On POSIX systems, this encodes major and minor device numbers.
    /// On Windows, this is synthesized from the volume serial number.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stats1 = try Kernel.File.Stats.get(path1)
    /// let stats2 = try Kernel.File.Stats.get(path2)
    /// if stats1.device == stats2.device {
    ///     // Both files are on the same filesystem
    /// }
    /// ```
    public struct Device: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt64

        /// Creates a device ID from a raw value.
        @inlinable
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// Creates a device ID from a UInt64 value.
        @inlinable
        public init(_ value: UInt64) {
            self.rawValue = value
        }

        // MARK: - Major/Minor Extraction (POSIX)

        #if !os(Windows)
            /// The major device number (identifies device type/driver).
            ///
            /// This uses the standard Linux encoding for dev_t.
            @inlinable
            public var major: UInt32 {
                UInt32((rawValue >> 8) & 0xFFF)
            }

            /// The minor device number (identifies specific device instance).
            ///
            /// This uses the standard Linux encoding for dev_t.
            @inlinable
            public var minor: UInt32 {
                UInt32((rawValue & 0xFF) | ((rawValue >> 12) & 0xFFF00))
            }

            /// Creates a device ID from major and minor numbers.
            @inlinable
            public init(major: UInt32, minor: UInt32) {
                let majorPart = UInt64(major & 0xFFF) << 8
                let minorLow = UInt64(minor & 0xFF)
                let minorHigh = UInt64((minor & 0xFFF00)) << 12
                self.rawValue = majorPart | minorLow | minorHigh
            }
        #endif
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Kernel.Device: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Device: CustomStringConvertible {
    public var description: String {
        #if os(Windows)
            return "\(rawValue)"
        #else
            return "\(major):\(minor)"
        #endif
    }
}

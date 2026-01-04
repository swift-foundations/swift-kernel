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
    /// Flags controlling mapping behavior.
    public struct Flags: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Combines multiple flags.
        @inlinable
        public static func | (lhs: Flags, rhs: Flags) -> Flags {
            Flags(rawValue: lhs.rawValue | rhs.rawValue)
        }
    }
}

// MARK: - POSIX Constants

#if !os(Windows)

    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Memory.Map.Flags {
        /// Changes are shared with other processes.
        public static let shared = Self(rawValue: MAP_SHARED)

        /// Changes are private (copy-on-write).
        public static let `private` = Self(rawValue: MAP_PRIVATE)

        /// Anonymous mapping (not backed by a file).
        public static let anonymous = Self(rawValue: MAP_ANON)

        /// Mapping must be at the specified address (hint becomes requirement).
        public static let fixed = Self(rawValue: MAP_FIXED)
    }

#endif

// MARK: - Windows Constants

#if os(Windows)

    extension Kernel.Memory.Map.Flags {
        /// Changes are shared.
        public static let shared = Self(rawValue: 1)

        /// Changes are private (copy-on-write).
        public static let `private` = Self(rawValue: 2)

        /// Anonymous mapping.
        public static let anonymous = Self(rawValue: 4)

        /// Fixed address.
        public static let fixed = Self(rawValue: 8)
    }

#endif

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

#if canImport(Glibc) || canImport(Musl)

#if canImport(Glibc)
public import Glibc
public import CLinuxShim
#elseif canImport(Musl)
internal import Musl
#endif

extension Kernel.Event.Poll {
    /// Flags for `epoll_create1`.
    public struct CreateFlags: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Event.Poll.CreateFlags {
    /// No flags.
    public static let none = Self(rawValue: 0)

    /// Set close-on-exec flag on the new file descriptor.
    public static let cloexec = Self(rawValue: Int32(EPOLL_CLOEXEC))

    /// Combines multiple flags.
    @inlinable
    public static func | (lhs: Self, rhs: Self) -> Self {
        Self(rawValue: lhs.rawValue | rhs.rawValue)
    }
}

#endif

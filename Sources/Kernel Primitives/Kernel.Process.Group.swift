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

#if !os(Windows)

#if canImport(Darwin)
    public import Darwin
#elseif canImport(Glibc)
    public import Glibc
#elseif canImport(Musl)
    public import Musl
#endif

// MARK: - Process.Group.ID

extension Kernel.Process.Group {
    /// POSIX process group ID.
    ///
    /// A type-safe wrapper for process group identifiers used in signal sending.
    ///
    /// Distinct from `Process.ID` to prevent accidentally passing a PGID
    /// where a PID is required (or vice versa).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Send signal to a process group
    /// try Kernel.Signal.Send.toGroup(.terminate, pgid: .current)
    /// ```
    public typealias ID = Tagged<Kernel.Process.Group, pid_t>
}

// MARK: - Process.Group.ID Constants

extension Tagged where Tag == Kernel.Process.Group, RawValue == pid_t {
    /// The current process group.
    @inlinable
    public static var current: Self { Self(getpgrp()) }
}

#endif

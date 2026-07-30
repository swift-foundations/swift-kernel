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

extension Kernel.Event {
    /// Readiness categories for descriptor monitoring.
    ///
    /// Cross-paradigm vocabulary — shared by reactor-style readiness
    /// (``Kernel/Event``) and proactor-style completion polling
    /// (``Kernel/Completion``). The concept is unitary across platforms;
    /// the encoding into platform-specific masks/filters happens at the
    /// spec layer (L2) via per-platform projection initializers.
    ///
    /// ## Platform Mapping
    ///
    /// | Interest     | POSIX poll    | Linux epoll | Linux io_uring POLL | Darwin kqueue (expansion) | Windows WSAPoll |
    /// |--------------|---------------|-------------|----------------------|---------------------------|-----------------|
    /// | `.read`      | `POLLIN`      | `EPOLLIN`   | `POLLIN`             | `EVFILT_READ` kevent      | `POLLRDNORM`    |
    /// | `.write`     | `POLLOUT`     | `EPOLLOUT`  | `POLLOUT`            | `EVFILT_WRITE` kevent     | `POLLWRNORM`    |
    /// | `.priority`  | `POLLPRI`     | `EPOLLPRI`  | `POLLPRI`            | `EV_OOBAND` (indirect)    | `POLLPRI`       |
    public struct Interest: OptionSet, Sendable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Event.Interest {
    /// Interest in read readiness (data available to read).
    public static let read = Self(rawValue: 1 << 0)

    /// Interest in write readiness (buffer space available for writing).
    public static let write = Self(rawValue: 1 << 1)

    /// Interest in priority/out-of-band data (platform-specific).
    public static let priority = Self(rawValue: 1 << 2)
}

extension Kernel.Event.Interest: CustomStringConvertible {
    public var description: Swift.String {
        var parts: [Swift.String] = []
        if contains(.read) { parts.append("read") }
        if contains(.write) { parts.append("write") }
        if contains(.priority) { parts.append("priority") }
        return parts.isEmpty ? "none" : parts.joined(separator: "|")
    }
}

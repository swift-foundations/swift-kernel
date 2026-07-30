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
    /// Additional status flags accompanying an event.
    ///
    /// Options provide supplementary information about the event, such as
    /// whether an error occurred or whether the peer closed the connection.
    ///
    /// ## Platform Mapping
    /// - **kqueue**: `EV_EOF`, `EV_ERROR`
    /// - **epoll**: `EPOLLERR`, `EPOLLHUP`, `EPOLLRDHUP`
    /// - **IOCP**: Derived from completion status and WSA errors
    public struct Options: OptionSet, Sendable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Event.Options {
    /// An error occurred on the descriptor.
    public static let error = Self(rawValue: 1 << 0)

    /// The connection has been closed or reset.
    public static let hangup = Self(rawValue: 1 << 1)

    /// The peer closed the read side (sent FIN).
    public static let readHangup = Self(rawValue: 1 << 2)

    /// The peer closed the write side.
    public static let writeHangup = Self(rawValue: 1 << 3)
}

extension Kernel.Event.Options: CustomStringConvertible {
    public var description: Swift.String {
        var parts: [Swift.String] = []
        if contains(.error) { parts.append("error") }
        if contains(.hangup) { parts.append("hangup") }
        if contains(.readHangup) { parts.append("readHangup") }
        if contains(.writeHangup) { parts.append("writeHangup") }
        return parts.isEmpty ? "none" : parts.joined(separator: "|")
    }
}

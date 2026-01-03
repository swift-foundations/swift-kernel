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

extension Kernel.Error {
    /// I/O operation error conditions.
    public enum IO: Sendable, Equatable {
        /// The pipe or socket peer has closed the connection.
        /// - POSIX: `EPIPE`
        /// - Windows: `ERROR_BROKEN_PIPE`
        case broken

        /// The connection was reset by the remote peer.
        /// - POSIX: `ECONNRESET`
        case reset

        /// Device-related errors.
        case device(Device)

        /// Illegal seek on a non-seekable descriptor (e.g., pipe, socket).
        /// - POSIX: `ESPIPE`
        case seek
    }
}

extension Kernel.Error.IO: CustomStringConvertible {
    public var description: String {
        switch self {
        case .broken: return "broken pipe"
        case .reset: return "connection reset"
        case .device(let device): return device.description
        case .seek: return "illegal seek"
        }
    }
}

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

extension Kernel.Error.IO {
    /// Device error types.
    public enum Device: Sendable, Equatable {
        /// The device does not support the requested operation.
        /// - POSIX: `ENODEV`
        case unsupported

        /// The device does not exist or is not configured.
        /// - POSIX: `ENXIO`
        /// - Windows: `ERROR_IO_DEVICE`
        case unavailable
    }
}

extension Kernel.Error.IO.Device: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupported: return "operation not supported by device"
        case .unavailable: return "device unavailable"
        }
    }
}

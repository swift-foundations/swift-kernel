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

extension Kernel.Signal {
    /// Signal-related errors.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Operation interrupted by signal.
        /// - POSIX: `EINTR`
        case interrupted
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Signal.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .interrupted:
            return "interrupted by signal"
        }
    }
}

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
    /// File locking error conditions.
    public enum Lock: Sendable, Equatable {
        /// A deadlock condition was detected.
        /// - POSIX: `EDEADLK`
        case deadlock

        /// No record locks available (system lock table full).
        /// - POSIX: `ENOLCK`
        ///
        /// - Note: This is resource exhaustion, not "lock held by someone else".
        case unavailable
    }
}

extension Kernel.Error.Lock: CustomStringConvertible {
    public var description: String {
        switch self {
        case .deadlock: return "deadlock"
        case .unavailable: return "no locks available"
        }
    }
}

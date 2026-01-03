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
    /// Memory error conditions.
    public enum Memory: Sendable, Equatable {
        /// An invalid memory address was provided.
        /// - POSIX: `EFAULT`
        case address

        /// Not enough memory available.
        /// - POSIX: `ENOMEM`
        /// - Windows: `ERROR_NOT_ENOUGH_MEMORY`
        case exhausted
    }
}

extension Kernel.Error.Memory: CustomStringConvertible {
    public var description: String {
        switch self {
        case .address: return "invalid address"
        case .exhausted: return "out of memory"
        }
    }
}

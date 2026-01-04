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

extension Kernel.Lock {
    /// Lock type (shared vs exclusive).
    public enum Kind: Sendable, Equatable, Hashable {
        /// Shared (read) lock. Multiple processes can hold shared locks.
        case shared

        /// Exclusive (write) lock. Only one process can hold an exclusive lock.
        case exclusive
    }
}

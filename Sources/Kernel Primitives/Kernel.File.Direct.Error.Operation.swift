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

extension Kernel.File.Direct.Error {
    /// Direct I/O operation types for syscall error context.
    public enum Operation: String, Sendable, Equatable {
        case open
        case setNoCache
        case clearNoCache
        case getSectorSize
        case read
        case write
    }
}

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

extension Kernel.File.Direct.Error {
    /// Direct I/O operation types for syscall error context.
    public enum Operation: Sendable, Equatable {
        case open
        case cache(Cache)
        case sector(Sector)
        case read
        case write
    }
}

extension Kernel.File.Direct.Error.Operation {
    /// Cache operation types.
    public enum Cache: Swift.String, Sendable, Equatable {
        case set
        case clear
    }

    /// Sector operation types.
    public enum Sector: Swift.String, Sendable, Equatable {
        case getSize
    }
}

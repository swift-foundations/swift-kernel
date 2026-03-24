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

public import Kernel_Primitives

extension Kernel.File.Write.Streaming {
    /// Controls durability guarantees for streaming writes.
    public enum Durability: Sendable, Equatable {
        /// Full durability - both data and metadata synced.
        /// Uses `F_FULLFSYNC` on Darwin, `fsync` elsewhere.
        case full

        /// Data-only sync - metadata may not be persisted.
        /// Uses `F_BARRIERFSYNC` on Darwin, `fdatasync` on Linux.
        case dataOnly

        /// No sync - rely on OS buffers.
        /// Faster but data may be lost on power failure.
        case none
    }
}

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

extension Kernel.File.Write {
    /// Internal durability mode shared between `Atomic` and `Streaming`.
    internal enum Durability: Sendable {
        case full
        case dataOnly
        case none
    }
}

extension Kernel.File.Write.Atomic.Durability {
    internal var unified: Kernel.File.Write.Durability {
        switch self {
        case .full: .full
        case .dataOnly: .dataOnly
        case .none: .none
        }
    }
}

extension Kernel.File.Write.Streaming.Durability {
    internal var unified: Kernel.File.Write.Durability {
        switch self {
        case .full: .full
        case .dataOnly: .dataOnly
        case .none: .none
        }
    }
}

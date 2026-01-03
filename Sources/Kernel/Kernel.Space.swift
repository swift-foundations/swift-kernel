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

extension Kernel {
    /// Space domain - storage space exhaustion.
    ///
    /// These errors indicate the filesystem cannot allocate
    /// additional storage for the operation.
    public enum Space: Sendable {

    }
}

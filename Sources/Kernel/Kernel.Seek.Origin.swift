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

extension Kernel.Seek {
    /// Reference point for seek operations.
    public enum Origin: Sendable {
        /// Seek from the beginning of the file.
        case start

        /// Seek from the current file offset.
        case current

        /// Seek from the end of the file.
        case end
    }
}

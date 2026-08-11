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

extension Kernel.Thread.Run {
    /// A failure from one phase of structured thread execution.
    public enum Error<Failure: Swift.Error>: Swift.Error {
        /// The operating system did not create the thread.
        case creation(Kernel.Thread.Error)

        /// The operating system did not complete the physical join.
        case join(Kernel.Thread.Error)

        /// The operation running on the dedicated thread failed.
        case operation(Failure)
    }
}

extension Kernel.Thread.Run.Error: Sendable where Failure: Sendable {}
extension Kernel.Thread.Run.Error: Equatable where Failure: Equatable {}

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
    /// Signal domain - POSIX signal handling.
    ///
    /// Operations may be interrupted by signals. When this happens,
    /// the syscall returns `EINTR` and the operation must be retried
    /// by the caller if desired.
    ///
    /// ## Design
    /// Kernel does NOT automatically retry on `EINTR`. Higher layers
    /// decide retry policy based on their semantics.
    public enum Signal: Sendable {

    }
}

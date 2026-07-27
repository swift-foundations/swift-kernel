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

extension Tagged where Underlying == CPU.Atomic.Flag, Tag: ~Copyable & ~Escapable {
    /// Whether the flag has been set.
    ///
    /// Uses acquiring memory ordering.
    @inlinable
    public var isSet: Bool { underlying.isSet }

    /// Sets the flag. Idempotent.
    ///
    /// Uses releasing memory ordering.
    @inlinable
    public func set() { underlying.set() }
}

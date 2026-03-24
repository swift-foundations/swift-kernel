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

extension Tagged where RawValue == Kernel.Atomic.Flag, Tag: ~Copyable {
    /// Whether the flag has been set.
    ///
    /// Uses acquiring memory ordering.
    @inlinable
    public var isSet: Bool { rawValue.isSet }

    /// Sets the flag. Idempotent.
    ///
    /// Uses releasing memory ordering.
    @inlinable
    public func set() { rawValue.set() }
}

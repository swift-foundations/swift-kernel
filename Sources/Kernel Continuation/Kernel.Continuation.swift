//
//  Kernel.Continuation.swift
//  swift-kernel
//
//  Created by Coen ten Thije Boonkkamp on 06/01/2026.
//

extension Kernel {
    /// Namespace for continuation-related types.
    ///
    /// These types help bridge blocking/synchronous work to Swift's async world
    /// with exactly-once resumption guarantees.
    public enum Continuation {}
}

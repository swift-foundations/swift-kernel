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

extension Kernel.Thread.Handle {
    // WORKAROUND: Compound name — consuming ~Copyable prevents Property.Inout accessor
    // WHY: join() must consume self; Property.Inout borrows
    // WHEN TO REMOVE: When Swift supports consuming property accessors
    // TRACKING: swift-kernel-deep-audit [API-NAME-002]
    /// Waits for the thread to complete with a safety check.
    ///
    /// This is a convenience that adds a precondition to prevent join-on-self
    /// deadlock. Use this when you want the safety of `Worker.join()` but are
    /// using raw `spawn`/`trap`.
    ///
    /// The raw `join()` in Kernel Primitives does not include this check,
    /// preserving "close-to-the-metal" behavior for advanced use cases.
    ///
    /// - Precondition: Must NOT be called from this thread (deadlock).
    /// - Note: Must be called exactly once. The `~Copyable` constraint enforces this.
    @inlinable
    public consuming func joinChecked() {
        precondition(
            isCurrent == false,
            "Kernel.Thread.Handle.joinChecked() called from the thread being joined - this would deadlock"
        )
        join()
    }
}

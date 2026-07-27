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
    /// Reference wrapper for storing `~Copyable` handle in arrays.
    ///
    /// This class allows storing `Kernel.Thread.Handle` (which is `~Copyable`) in
    /// arrays and other Copyable containers. The reference type is Copyable,
    /// but the inner handle enforces exactly-once join semantics.
    ///
    /// ## Safety Invariant
    ///
    /// This type is `Sendable` by virtue of ownership transfer, not internal
    /// locking. It wraps a `~Copyable` `Kernel.Thread.Handle` in `inner:
    /// Kernel.Thread.Handle?`, and every live-state transition consumes the
    /// handle exactly once:
    /// - `join()` uses `inner.take()` to consume the handle; a second call
    ///   traps (`join() called twice`).
    /// - `deinit` preconditions `inner == nil` -- deallocation without join
    ///   traps, surfacing thread leaks at the earliest deterministic point.
    ///
    /// The caller's obligation is to guarantee that `join()` is driven from
    /// exactly one thread at exactly one point in the lifecycle, before the
    /// wrapper is deallocated. Cross-isolation transfer is sound because the
    /// wrapped handle's ownership invariant (exactly-once join) is honored
    /// by the wrapper, not by memcpy of bytes.
    ///
    /// ## Intended Use
    ///
    /// - Storing an array of in-flight thread handles at the orchestration
    ///   layer (e.g., pool drivers, multi-thread lifecycle managers) where
    ///   the `~Copyable` handle cannot be held in a `[T]` directly.
    /// - Producer / consumer handoff: one context spawns the thread and
    ///   moves the `Reference` to a lifecycle-management context that joins
    ///   all threads during shutdown.
    ///
    /// ## Non-Goals
    ///
    /// - Not a retain-on-clone handle. The wrapper is `Copyable` at the
    ///   class-reference layer, but the *thread-join obligation is still
    ///   exactly-once* -- cloning the reference does not clone the obligation.
    /// - Not safe to `join()` concurrently from multiple threads. The second
    ///   call traps.
    /// - Not a substitute for `Kernel.Thread.Handle` where a direct
    ///   `~Copyable` value suffices.
    ///
    /// ## Usage
    /// ```swift
    /// var threads: [Kernel.Thread.Handle.Reference] = []
    /// let handle = Kernel.Thread.trap { ... }
    /// threads.append(Reference(handle))
    ///
    /// // Later: join all threads
    /// for thread in threads { thread.join() }
    /// ```
    public final class Reference: @unsafe @unchecked Sendable {
        private var inner: Kernel.Thread.Handle?

        /// Creates a wrapper owning the given thread handle.
        public init(_ handle: consuming Kernel.Thread.Handle) {
            self.inner = consume handle
        }

        deinit {
            // Verify handle was joined - if not, we're leaking a thread
            precondition(
                inner == nil,
                "Kernel.Thread.Handle.Reference deallocated without join()"
            )
        }
    }
}

extension Kernel.Thread.Handle.Reference {
    /// Joins the thread, consuming the handle.
    ///
    /// - Precondition: Must be called exactly once.
    public func join() {
        guard let handle = inner.take() else {
            preconditionFailure(
                "Kernel.Thread.Handle.Reference.join() called twice"
            )
        }
        handle.join()
    }
}

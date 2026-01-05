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
    /// Reference wrapper for storing ~Copyable handle in arrays.
    ///
    /// This class allows storing `Kernel.Thread.Handle` (which is ~Copyable) in
    /// arrays and other Copyable containers. The reference type is Copyable,
    /// but the inner handle enforces exactly-once join semantics.
    ///
    /// ## Usage
    /// ```swift
    /// var threads: [Kernel.Thread.Handle.Reference] = []
    /// let handle = Kernel.Thread.trap { ... }
    /// threads.append(Reference(handle))
    ///
    /// // Later: join all threads
    /// for thread in threads {
    ///     thread.join()
    /// }
    /// ```
    ///
    /// ## Safety Invariant
    /// - `join()` consumes the inner handle exactly once
    /// - Calling `join()` twice traps with a diagnostic message
    /// - The `deinit` verifies the handle was joined (no leaked threads)
    ///
    /// ## Thread Safety
    /// This type is `@unchecked Sendable` because:
    /// - The handle is only accessed from controlled lifecycle code
    /// - `join()` is called exactly once during shutdown
    public final class Reference: @unchecked Sendable {
        private var inner: Kernel.Thread.Handle?

        /// Creates a wrapper owning the given thread handle.
        public init(_ handle: consuming Kernel.Thread.Handle) {
            self.inner = consume handle
        }

        /// Joins the thread, consuming the handle.
        ///
        /// - Precondition: Must be called exactly once.
        public func join() {
            guard let handle = inner._take() else {
                preconditionFailure(
                    "Kernel.Thread.Handle.Reference.join() called twice"
                )
            }
            handle.join()
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

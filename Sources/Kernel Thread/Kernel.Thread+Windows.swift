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

// Windows forwarders for the two `Kernel.Thread` operations that are not
// types. Before swift-foundations/swift-windows#2, `Windows.Kernel.Thread`
// was a whole-namespace typealias and every member — including static
// functions — forwarded implicitly. It is now a distinct policy enum whose
// per-member typealiases can only carry types, so `create` and `yield` need
// real forwarding declarations for the cross-platform surface to hold. The
// POSIX side has the mirror pair on `POSIX.Kernel.Thread`.

#if os(Windows)

    // The L3-policy module carries the `Kernel.Thread.{Error,Handle}`
    // typealiases in the signatures below; the L2 module carries the
    // mechanisms they forward to.
    public import Windows_32_Kernel_Thread
    public import Windows_Kernel_Thread

    extension Kernel.Thread {
        /// Creates and starts an OS thread running `body`.
        ///
        /// - Parameter body: The work to run on the new thread, invoked exactly once.
        /// - Returns: A handle to the running thread.
        /// - Throws: `Kernel.Thread.Error` if thread creation fails.
        @inlinable
        public static func create(
            _ body: @escaping @Sendable () -> Void
        ) throws(Kernel.Thread.Error) -> Kernel.Thread.Handle {
            try Windows.`32`.Kernel.Thread.create(body)
        }

        /// Offers the remainder of the calling thread's time slice to the scheduler.
        @inlinable
        public static func yield() {
            Windows.`32`.Kernel.Thread.yield()
        }
    }

#endif

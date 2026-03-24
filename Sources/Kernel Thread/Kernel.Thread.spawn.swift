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

extension Kernel.Thread {
    /// Thread spawning callable type.
    ///
    /// Provides a clean `Kernel.Thread.spawn { ... }` syntax via `callAsFunction`.
    ///
    /// ## Usage
    /// ```swift
    /// // Throwing (preferred for robust code)
    /// let handle = try Kernel.Thread.spawn { print("Hello from thread") }
    ///
    /// // With value transfer
    /// let handle = try Kernel.Thread.spawn(myValue) { value in
    ///     process(value)
    /// }
    /// ```
    ///
    /// ## Failure Handling
    /// Thread creation can fail due to resource limits (RLIMIT_NPROC),
    /// memory pressure, OS policy, or sandboxing. On failure:
    /// - The context pointer is properly deallocated (no leaks)
    /// - The closure is NOT invoked
    /// - The platform error code is preserved in the thrown error
    public struct Spawn: Sendable {
        @usableFromInline
        init() {}
    }

    /// Entry point for thread spawning.
    ///
    /// Usage: `let handle = try Kernel.Thread.spawn { ... }`
    public static var spawn: Spawn { Spawn() }
}

// MARK: - callAsFunction (Throwing)

extension Kernel.Thread.Spawn {
    /// Spawns a dedicated OS thread.
    ///
    /// The closure is invoked exactly once on the spawned OS thread.
    /// This guarantee is essential for ownership-transfer patterns using
    /// `Reference.Transfer.Cell`, where the closure takes ownership of a value
    /// that must be consumed exactly once.
    ///
    /// - Parameter body: The work to run on the new thread. Executed exactly once.
    /// - Returns: An opaque handle to the thread.
    /// - Throws: `Kernel.Thread.Error` if thread creation fails.
    @inlinable
    public func callAsFunction(
        _ body: @escaping @Sendable () -> Void
    ) throws(Kernel.Thread.Error) -> Kernel.Thread.Handle {
        try Kernel.Thread.create(body)
    }

    /// Spawns a dedicated OS thread with an explicit value.
    ///
    /// This variant accepts a `~Copyable` value that is passed to the closure,
    /// avoiding closure capture issues with move-only types. The value is
    /// transferred using `Ownership.Transfer.Cell`, the single audited mechanism for
    /// cross-boundary ownership transfer.
    ///
    /// - Parameters:
    ///   - value: A value to pass to the thread. Ownership is transferred.
    ///   - body: The work to run, receiving the value. Executed exactly once.
    /// - Returns: An opaque handle to the thread.
    /// - Throws: `Kernel.Thread.Error` if thread creation fails.
    @inlinable
    public func callAsFunction<T: ~Copyable>(
        _ value: consuming T,
        _ body: @escaping @Sendable (consuming T) -> Void
    ) throws(Kernel.Thread.Error) -> Kernel.Thread.Handle {
        // Use Ownership.Transfer for cross-boundary ownership transfer
        let cell = Ownership.Transfer.Cell(value)
        let token = cell.token()

        return try self {
            let v = token.take()
            body(v)
        }
    }
}

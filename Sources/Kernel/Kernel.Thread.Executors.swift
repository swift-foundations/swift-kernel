//
//  Kernel.Thread.Executors.swift
//  swift-kernel
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

import Synchronization

extension Kernel.Thread {
    /// A sharded pool of serial executors for actor pinning.
    ///
    /// Pools are assigned to executors via round-robin at creation time.
    /// This provides:
    /// - Bounded thread count (default: min(4, processorCount))
    /// - Latency isolation between pools on different shards
    /// - Predictable scheduling topology
    ///
    /// ## Thread Safety
    /// This type is `Sendable`. The round-robin counter uses atomic operations,
    /// making `next()` safe to call from any thread without synchronization.
    ///
    /// ## Lifecycle Requirements
    /// **IMPORTANT**: The pool owns its executor threads and must be explicitly shut down:
    ///
    /// 1. Call `shutdown()` before the pool is deallocated
    /// 2. Do NOT call `shutdown()` from any of the executor threads (deadlock)
    /// 3. After shutdown, the pool cannot be reused
    ///
    /// ## Usage
    /// Typically accessed via `IO.Executor.shared`, but can also be instantiated
    /// directly for custom executor pool configurations.
    ///
    /// ```swift
    /// let pool = Kernel.Thread.Executors()
    /// defer { pool.shutdown() }
    ///
    /// let executor = pool.next()
    /// // Use executor for actor pinning
    /// ```
    public final class Executors: Sendable {
        private let executors: [Executor]
        private let counter: Atomic<UInt64>

        /// Creates a new executor pool with the given options.
        ///
        /// Threads start immediately upon pool creation.
        public init(_ options: Options = .init()) {
            self.executors = (0..<Int(options.count)).map { _ in Executor() }
            self.counter = Atomic(0)
        }
    }
}

extension Kernel.Thread.Executors {
    /// The number of executor threads in the pool.
    public var count: Int { executors.count }

    /// Get the next executor using round-robin assignment.
    ///
    /// Each call advances an internal counter, distributing pools evenly
    /// across available executor threads.
    ///
    /// ## Thread Safety
    /// This method is safe to call from any thread. The counter uses atomic
    /// `wrappingAdd` with relaxed ordering, which is sufficient for distribution
    /// purposes (strict ordering is not required for round-robin assignment).
    ///
    /// - Returns: The next executor in the round-robin sequence.
    public func next() -> Kernel.Thread.Executor {
        let index = counter.wrappingAdd(1, ordering: .relaxed).oldValue
        return executors[Int(index) % executors.count]
    }

    /// Get a specific executor by index.
    ///
    /// Useful for explicit pinning when you want control over which
    /// executor a pool uses.
    ///
    /// - Parameter index: The executor index (wraps around if >= count).
    public func executor(at index: Int) -> Kernel.Thread.Executor {
        executors[index % executors.count]
    }

    /// Shutdown all executor threads in the pool.
    ///
    /// Signals each executor's run loop to exit after processing remaining jobs,
    /// then joins all threads. This method blocks until all threads have terminated.
    ///
    /// ## Threading
    /// - **Blocking**: This method blocks the calling thread until all executor
    ///   threads have completed.
    /// - **Precondition**: Must NOT be called from any of the executor threads.
    ///   Doing so would deadlock (joining a thread from itself).
    ///
    /// ## Lifecycle
    /// - Must be called exactly once before the pool is deallocated
    /// - After shutdown, the pool cannot be reused
    /// - Jobs enqueued after shutdown begins are silently dropped
    public func shutdown() {
        for executor in executors {
            executor.shutdown()
        }
    }
}

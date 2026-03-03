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
    /// Mutex + N condition variable(s) wrapper.
    ///
    /// Parameterized by condition count for compile-time safety:
    /// - `Synchronization<1>` - single condition (executor job queue)
    /// - `Synchronization<2>` - dual conditions (worker/deadline separation)
    ///
    /// Uses `InlineArray` for zero-allocation fixed-size storage.
    ///
    /// ## Safety
    /// `@unchecked Sendable` because it provides internal synchronization.
    /// All access to protected data must occur within `withLock` or while holding the lock.
    ///
    /// ## Usage
    /// ```swift
    /// let sync = Kernel.Thread.Synchronization<2>()
    ///
    /// sync.lock()
    /// defer { sync.unlock() }
    ///
    /// // Wait on condition 0 (worker)
    /// sync.wait(condition: 0)
    ///
    /// // Signal condition 1 (deadline)
    /// sync.signal(condition: 1)
    /// ```
    public final class Synchronization<let N: Int>: @unchecked Sendable {
        private let mutex = Kernel.Thread.Mutex()
        private var conditions: InlineArray<N, Kernel.Thread.Condition>
        private var waiterCounts: InlineArray<N, Int>

        /// Creates synchronization with N condition variables.
        ///
        /// - Precondition: N must be at least 1.
        public init() {
            precondition(N >= 1, "Synchronization requires at least 1 condition variable")
            self.conditions = InlineArray { _ in Kernel.Thread.Condition() }
            self.waiterCounts = InlineArray { _ in 0 }
        }

        // MARK: - Lock Operations

        /// Acquire the lock.
        public func lock() {
            mutex.lock()
        }

        /// Release the lock.
        public func unlock() {
            mutex.unlock()
        }

        /// Execute a closure while holding the lock.
        public func withLock<T, E: Swift.Error>(_ body: () throws(E) -> T) throws(E) -> T {
            try mutex.withLock(body)
        }

        // MARK: - Condition Variable Operations

        /// Wait on the specified condition variable.
        ///
        /// Must be called while holding the lock.
        /// The lock is released while waiting and reacquired before returning.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Precondition: Index must be in range 0..<N.
        public func wait(condition index: Int = 0) {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            conditions[index].wait(mutex: mutex)
        }

        /// Wait on the specified condition variable with timeout.
        ///
        /// Must be called while holding the lock.
        /// The lock is released while waiting and reacquired before returning.
        ///
        /// - Parameters:
        ///   - condition: Index of condition variable (0..<N).
        ///   - nanoseconds: Timeout in nanoseconds. Values exceeding Int64.max are clamped.
        /// - Returns: `true` if signaled, `false` if timed out.
        /// - Precondition: Index must be in range 0..<N.
        public func wait(condition index: Int = 0, timeout nanoseconds: UInt64) -> Bool {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            let clampedNanos = Int64(clamping: nanoseconds)
            return conditions[index].wait(mutex: mutex, timeout: .nanoseconds(clampedNanos))
        }

        /// Wait on the specified condition variable with Duration timeout.
        ///
        /// Must be called while holding the lock.
        /// The lock is released while waiting and reacquired before returning.
        ///
        /// - Parameters:
        ///   - condition: Index of condition variable (0..<N).
        ///   - timeout: Maximum duration to wait.
        /// - Returns: `true` if signaled, `false` if timed out.
        /// - Precondition: Index must be in range 0..<N.
        public func wait(condition index: Int = 0, timeout: Duration) -> Bool {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            return conditions[index].wait(mutex: mutex, timeout: timeout)
        }

        /// Signal one thread waiting on the specified condition variable.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Precondition: Index must be in range 0..<N.
        public func signal(condition index: Int = 0) {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            conditions[index].signal()
        }

        /// Signal all threads waiting on the specified condition variable.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Precondition: Index must be in range 0..<N.
        public func broadcast(condition index: Int = 0) {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            conditions[index].broadcast()
        }

        /// Signal all threads waiting on all condition variables.
        public func broadcastAll() {
            for i in 0..<N {
                conditions[i].broadcast()
            }
        }

        // MARK: - Waiter Tracking Operations

        /// Returns the current waiter count for the specified condition.
        ///
        /// Must be called while holding the lock.
        ///
        /// - Note: This value is only semantically valid if all waits on this condition
        ///   use `waitTracked` during the period in which you rely on this count.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Returns: Number of threads currently waiting on this condition.
        /// - Precondition: Index must be in range 0..<N.
        public func waiterCount(for condition: Int = 0) -> Int {
            precondition(condition >= 0 && condition < N, "Condition index \(condition) out of bounds (0..<\(N))")
            return waiterCounts[condition]
        }

        /// Wait on the specified condition variable while tracking waiter count.
        ///
        /// Must be called while holding the lock.
        /// The lock is released while waiting and reacquired before returning.
        /// Waiter count is incremented before waiting and decremented after.
        ///
        /// - Note: For correct waiter counts, all waits on this condition should use
        ///   `waitTracked` rather than mixing with `wait`.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Precondition: Index must be in range 0..<N.
        public func waitTracked(condition index: Int = 0) {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            waiterCounts[index] += 1
            defer {
                waiterCounts[index] -= 1
                assert(waiterCounts[index] >= 0, "Waiter count underflow")
            }
            conditions[index].wait(mutex: mutex)
        }

        /// Wait on the specified condition variable with timeout while tracking waiter count.
        ///
        /// Must be called while holding the lock.
        /// The lock is released while waiting and reacquired before returning.
        /// Waiter count is incremented before waiting and decremented after.
        ///
        /// - Note: For correct waiter counts, all waits on this condition should use
        ///   `waitTracked` rather than mixing with `wait`.
        ///
        /// - Parameters:
        ///   - condition: Index of condition variable (0..<N).
        ///   - timeout: Maximum duration to wait.
        /// - Returns: `true` if signaled, `false` if timed out.
        /// - Precondition: Index must be in range 0..<N.
        public func waitTracked(condition index: Int = 0, timeout: Duration) -> Bool {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            waiterCounts[index] += 1
            defer {
                waiterCounts[index] -= 1
                assert(waiterCounts[index] >= 0, "Waiter count underflow")
            }
            return conditions[index].wait(mutex: mutex, timeout: timeout)
        }

        /// Signal one thread if any are waiting on the specified condition.
        ///
        /// Skips the signal syscall if no waiters exist.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Returns: `true` if signal was sent (waiters existed), `false` if skipped.
        /// - Precondition: Index must be in range 0..<N.
        public func signalIfWaiters(condition index: Int = 0) -> Bool {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            guard waiterCounts[index] > 0 else { return false }
            conditions[index].signal()
            return true
        }

        /// Broadcast to all threads if any are waiting on the specified condition.
        ///
        /// Skips the broadcast syscall if no waiters exist.
        ///
        /// - Parameter condition: Index of condition variable (0..<N).
        /// - Returns: `true` if broadcast was sent (waiters existed), `false` if skipped.
        /// - Precondition: Index must be in range 0..<N.
        public func broadcastIfWaiters(condition index: Int = 0) -> Bool {
            precondition(index >= 0 && index < N, "Condition index \(index) out of bounds (0..<\(N))")
            guard waiterCounts[index] > 0 else { return false }
            conditions[index].broadcast()
            return true
        }
    }
}

// MARK: - Common Typealiases

extension Kernel.Thread {
    /// Single condition variable synchronization.
    ///
    /// Use for simple producer-consumer patterns like executor job queues.
    public typealias SingleSync = Synchronization<1>

    /// Dual condition variable synchronization.
    ///
    /// Use for patterns requiring separate signaling channels,
    /// e.g., worker/deadline separation in blocking lane implementations.
    public typealias DualSync = Synchronization<2>
}

// MARK: - Convenience for Dual Sync

extension Kernel.Thread.Synchronization where N == 2 {
    /// Accessor for worker condition (index 0).
    public var worker: ConditionAccessor {
        ConditionAccessor(sync: self, index: 0)
    }

    /// Accessor for deadline condition (index 1).
    public var deadline: ConditionAccessor {
        ConditionAccessor(sync: self, index: 1)
    }

    /// Accessor for a specific condition variable.
    public struct ConditionAccessor: Sendable {
        private let sync: Kernel.Thread.Synchronization<2>
        private let index: Int

        init(sync: Kernel.Thread.Synchronization<2>, index: Int) {
            self.sync = sync
            self.index = index
        }

        /// Wait on this condition.
        public func wait() {
            sync.wait(condition: index)
        }

        /// Wait on this condition with timeout.
        public func wait(timeout nanoseconds: UInt64) -> Bool {
            sync.wait(condition: index, timeout: nanoseconds)
        }

        /// Wait on this condition with Duration timeout.
        public func wait(timeout: Duration) -> Bool {
            sync.wait(condition: index, timeout: timeout)
        }

        /// Signal one waiter on this condition.
        public func signal() {
            sync.signal(condition: index)
        }

        /// Broadcast to all waiters on this condition.
        public func broadcast() {
            sync.broadcast(condition: index)
        }

        // MARK: - Waiter Tracking

        /// Current waiter count for this condition.
        ///
        /// Only valid if all waits use `waitTracked`.
        public var waiterCount: Int {
            sync.waiterCount(for: index)
        }

        /// Wait on this condition while tracking waiter count.
        public func waitTracked() {
            sync.waitTracked(condition: index)
        }

        /// Wait on this condition with timeout while tracking waiter count.
        public func waitTracked(timeout: Duration) -> Bool {
            sync.waitTracked(condition: index, timeout: timeout)
        }

        /// Signal one waiter if any exist on this condition.
        @discardableResult
        public func signalIfWaiters() -> Bool {
            sync.signalIfWaiters(condition: index)
        }

        /// Broadcast if any waiters exist on this condition.
        @discardableResult
        public func broadcastIfWaiters() -> Bool {
            sync.broadcastIfWaiters(condition: index)
        }
    }
}

extension Kernel.Thread.DualSync {
    /// Accessor for broadcasting all conditions.
    public struct BroadcastAll: Sendable {
        private let sync: Kernel.Thread.DualSync

        init(sync: Kernel.Thread.DualSync) {
            self.sync = sync
        }

        /// Broadcast all conditions.
        public func all() {
            sync.broadcastAll()
        }
    }

    /// Broadcast all conditions accessor.
    public var broadcast: BroadcastAll {
        BroadcastAll(sync: self)
    }
}

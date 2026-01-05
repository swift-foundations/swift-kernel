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

extension Kernel.Thread.Executor {
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
    /// let sync = Synchronization<2>()
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

        /// Creates synchronization with N condition variables.
        ///
        /// - Precondition: N must be at least 1.
        public init() {
            precondition(N >= 1, "Synchronization requires at least 1 condition variable")
            self.conditions = InlineArray { _ in Kernel.Thread.Condition() }
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
        public func withLock<T>(_ body: () throws -> T) rethrows -> T {
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
    }
}

// MARK: - Common Typealiases

extension Kernel.Thread.Executor {
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

extension Kernel.Thread.Executor.Synchronization where N == 2 {
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
        private let sync: Kernel.Thread.Executor.Synchronization<2>
        private let index: Int

        init(sync: Kernel.Thread.Executor.Synchronization<2>, index: Int) {
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

        /// Signal one waiter on this condition.
        public func signal() {
            sync.signal(condition: index)
        }

        /// Broadcast to all waiters on this condition.
        public func broadcast() {
            sync.broadcast(condition: index)
        }
    }
}

extension Kernel.Thread.Executor.DualSync {
    /// Accessor for broadcasting all conditions.
    public struct BroadcastAll: Sendable {
        private let sync: Kernel.Thread.Executor.DualSync

        init(sync: Kernel.Thread.Executor.DualSync) {
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

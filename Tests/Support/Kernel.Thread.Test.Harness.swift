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

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// Test harness utilities for threading tests.
///
/// Provides a condvar-based coordination mechanism that eliminates:
/// - Cross-thread mutex unlock (undefined behavior)
/// - Data races on shared state
/// - Timing-based correctness assertions
///
/// Use `Harness<State>` to coordinate between test threads via:
/// - `update { }` for synchronized mutation plus broadcast
/// - `wait(until:)` for deterministic ordering
/// - `withLocked { }` for synchronized reads
public enum KernelThreadTest {
    /// Timeout error for `wait(until:)` operations.
    ///
    /// This is only used as a deadlock guard, not as a correctness signal.
    public struct Timeout: Swift.Error, Sendable, Equatable {
        public init() {}
    }

    /// Thread-safe state container with condvar-based signaling.
    ///
    /// Use this to coordinate between threads in tests without data races
    /// or cross-thread mutex unlock.
    ///
    /// ## Example
    /// ```swift
    /// struct State {
    ///     var workerStarted = false
    ///     var result: Bool? = nil
    /// }
    /// let h = KernelThreadTest.Harness(State())
    ///
    /// // Worker thread
    /// h.update { $0.workerStarted = true }
    /// let ok = someOperation()
    /// h.update { $0.result = ok }
    ///
    /// // Main thread
    /// try h.wait(until: { $0.workerStarted })
    /// try h.wait(until: { $0.result != nil })
    /// let result = h.withLocked { $0.result }
    /// ```
    public final class Harness<State>: @unchecked Sendable {
        private var mutex = pthread_mutex_t()
        private var cond = pthread_cond_t()
        private var state: State

        /// Creates a harness with the given initial state.
        public init(_ initial: State) {
            self.state = initial

            var m = pthread_mutex_t()
            var c = pthread_cond_t()

            pthread_mutex_init(&m, nil)
            pthread_cond_init(&c, nil)

            self.mutex = m
            self.cond = c
        }

        deinit {
            pthread_cond_destroy(&cond)
            pthread_mutex_destroy(&mutex)
        }

        /// Executes a closure with exclusive access to the state.
        ///
        /// Does not signal waiting threads. Use `update` if you need to signal.
        public func withLocked<R>(_ body: (inout State) -> R) -> R {
            pthread_mutex_lock(&mutex)
            defer { pthread_mutex_unlock(&mutex) }
            return body(&state)
        }

        /// Mutates the state and broadcasts to all waiting threads.
        ///
        /// Use this when changing state that other threads may be waiting on.
        public func update(_ body: (inout State) -> Void) {
            pthread_mutex_lock(&mutex)
            body(&state)
            pthread_cond_broadcast(&cond)
            pthread_mutex_unlock(&mutex)
        }

        /// Broadcasts to waiting threads without modifying state.
        public func signal() {
            pthread_mutex_lock(&mutex)
            pthread_cond_broadcast(&cond)
            pthread_mutex_unlock(&mutex)
        }

        /// Waits until the predicate returns true, with a timeout.
        ///
        /// The timeout is only a deadlock guard. Tests should not rely on
        /// timing for correctness; use ordering via `update`/`wait`.
        ///
        /// - Parameters:
        ///   - predicate: Condition to wait for.
        ///   - timeoutSeconds: Maximum time to wait (default 5 seconds).
        /// - Throws: `Timeout` if the predicate is not satisfied within the timeout.
        public func wait(
            until predicate: (State) -> Bool,
            timeoutSeconds: Int = 5
        ) throws(Timeout) {
            pthread_mutex_lock(&mutex)
            defer { pthread_mutex_unlock(&mutex) }

            if predicate(state) { return }

            var deadline = timespec()
            KernelThreadTest.clockRealtime(&deadline)
            KernelThreadTest.addSeconds(timeoutSeconds, to: &deadline)

            while !predicate(state) {
                let rc = pthread_cond_timedwait(&cond, &mutex, &deadline)
                if rc == ETIMEDOUT { throw Timeout() }
            }
        }
    }

    /// Gets the current realtime clock value.
    internal static func clockRealtime(_ out: inout timespec) {
        #if canImport(Darwin)
            var tv = timeval()
            gettimeofday(&tv, nil)
            out.tv_sec = tv.tv_sec
            out.tv_nsec = Int(tv.tv_usec) * 1_000
        #else
            var ts = timespec()
            clock_gettime(CLOCK_REALTIME, &ts)
            out = ts
        #endif
    }

    /// Adds seconds to a timespec.
    internal static func addSeconds(_ seconds: Int, to ts: inout timespec) {
        ts.tv_sec += seconds
    }
}

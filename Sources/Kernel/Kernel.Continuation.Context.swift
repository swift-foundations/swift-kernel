//
//  Kernel.Continuation.Context.swift
//  swift-kernel
//
//  Created by Coen ten Thije Boonkkamp on 06/01/2026.
//

public import Synchronization

extension Kernel.Continuation {
    /// Context for exactly-once continuation resumption.
    ///
    /// This class enables workers to resume a continuation directly,
    /// eliminating dictionary lookups. Uses atomic state to ensure exactly-once
    /// resumption between completion, cancellation, and failure paths.
    ///
    /// ## Typed Errors
    /// Uses `CheckedContinuation<Result<Success, Failure>, Never>` instead of
    /// a throwing continuation. This eliminates `any Error` propagation entirely.
    ///
    /// ## State Machine
    /// ```
    /// ┌─────────┐
    /// │ pending │ ──complete()──> [completed] ──resume(returning: .success(value))
    /// │   (0)   │ ──cancel()────> [cancelled] ──resume(returning: .failure(error))
    /// │         │ ──fail()──────> [failed]    ──resume(returning: .failure(error))
    /// └─────────┘
    /// ```
    ///
    /// ## Memory Ordering
    /// - compareExchange uses `.acquiringAndReleasing` for full fence
    /// - This ensures the continuation read happens-before the resume
    /// - And the state transition is visible to all racing paths
    ///
    /// ## Exactly-Once Guarantee
    /// Only one of complete/cancel/fail can succeed.
    /// All others return false and perform no action.
    ///
    /// ## Usage
    /// ```swift
    /// typealias Result = Swift.Result<Data, MyError>
    ///
    /// let result: Result = await withCheckedContinuation { continuation in
    ///     let context = Kernel.Continuation.Context<Data, MyError>(continuation: continuation)
    ///
    ///     // Store context for worker access
    ///     // Worker calls context.complete(data) or context.fail(error)
    ///     // Cancellation handler calls context.cancel(error)
    /// }
    /// ```
    public final class Context<Success: Sendable, Failure: Swift.Error & Sendable>: @unchecked Sendable {
        /// The continuation to resume with typed result.
        /// Uses non-throwing continuation with Result to eliminate `any Error`.
        private let continuation: CheckedContinuation<Swift.Result<Success, Failure>, Never>

        /// Atomic state tracking the resumption path.
        private let _state: Atomic<State>

        /// Resumption state for exactly-once continuation.
        @frozen
        public enum State: UInt8, AtomicRepresentable, Sendable {
            case pending = 0
            case completed = 1
            case cancelled = 2
            case failed = 3
        }

        /// Creates a context wrapping the given continuation.
        ///
        /// - Parameter continuation: A non-throwing checked continuation returning Result.
        public init(continuation: CheckedContinuation<Swift.Result<Success, Failure>, Never>) {
            self.continuation = continuation
            self._state = Atomic(.pending)
        }

        /// Attempt to complete with success. Returns true if this call resumed.
        ///
        /// Called by the worker after successful operation execution.
        ///
        /// - Parameter value: The success value to resume with.
        /// - Returns: `true` if this call performed the resumption, `false` if already resumed.
        @discardableResult
        public func complete(_ value: Success) -> Bool {
            let (exchanged, _) = _state.compareExchange(
                expected: .pending,
                desired: .completed,
                ordering: .acquiringAndReleasing
            )
            if exchanged {
                continuation.resume(returning: Swift.Result.success(value))
                return true
            }
            return false
        }

        /// Attempt to cancel with an error. Returns true if this call resumed.
        ///
        /// Semantically indicates Swift task cancellation. Called by cancellation handlers.
        ///
        /// - Parameter error: The cancellation error to resume with.
        /// - Returns: `true` if this call performed the resumption, `false` if already resumed.
        @discardableResult
        public func cancel(_ error: Failure) -> Bool {
            let (exchanged, _) = _state.compareExchange(
                expected: .pending,
                desired: .cancelled,
                ordering: .acquiringAndReleasing
            )
            if exchanged {
                continuation.resume(returning: Swift.Result.failure(error))
                return true
            }
            return false
        }

        /// Attempt to fail with an error. Returns true if this call resumed.
        ///
        /// Semantically indicates infrastructure failure (shutdown, queue full, timeout, etc.).
        ///
        /// - Parameter error: The failure error to resume with.
        /// - Returns: `true` if this call performed the resumption, `false` if already resumed.
        @discardableResult
        public func fail(_ error: Failure) -> Bool {
            let (exchanged, _) = _state.compareExchange(
                expected: .pending,
                desired: .failed,
                ordering: .acquiringAndReleasing
            )
            if exchanged {
                continuation.resume(returning: Swift.Result.failure(error))
                return true
            }
            return false
        }

        /// Check if already resumed (for debugging).
        public var isResumed: Bool {
            _state.load(ordering: .acquiring) != .pending
        }

        /// Get the current state for debugging.
        public var state: State {
            _state.load(ordering: .acquiring)
        }
    }
}

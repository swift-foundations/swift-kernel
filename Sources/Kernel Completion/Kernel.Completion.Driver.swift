
//
//  Kernel.Completion.Driver.swift
//  swift-kernel-primitives
//
//  Proactor witness — struct of closures capturing backend state.
//


extension Kernel.Completion {
    /// Kernel Completion Driver — Proactor Witness.
    ///
    /// A struct of closures capturing backend state. `~Copyable` — single
    /// ownership prevents aliasing of ring state. NOT `Sendable` —
    /// thread-confined to the completion poll thread after `sending` transfer.
    ///
    /// ## Five Operations
    ///
    /// - ``_submit``: enqueue an operation in the submission queue
    /// - ``_flush``: commit accumulated submissions to the kernel
    /// - ``_drain``: drain available completions via callback
    /// - ``_close``: tear down backend state
    /// - ``_overflowCount``: query cumulative overflow count
    ///
    /// ## Three-Boundary Completion Model
    ///
    /// - **Backend**: Raw platform completion entry → ``Event``.
    ///   Translates platform-specific fields and normalizes multishot
    ///   semantics (``Event/Flags/more``).
    /// - **Driver**: State lifecycle management, error domain translation,
    ///   and teardown orchestration. Does not filter events — all completions
    ///   correspond to submitted operations and are delivered to the visitor.
    /// - **Caller**: Consumes events, resolves continuations, maintains
    ///   dispatch tables for multishot and provided-buffer lifecycle.
    ///
    /// ## Drain-After-Notification
    ///
    /// ``_drain`` is a post-notification drain — it processes whatever is in
    /// the completion queue at the time of the call. It does not block. The
    /// blocking wait belongs to the event loop (epoll on Linux, IOCP on
    /// Windows).
    public struct Driver: ~Copyable {

        // MARK: - Witness Closures

        /// Enqueue a submission for the specified target descriptor.
        ///
        /// Writes the submission to the backend's submission queue. The
        /// operation is not committed to the kernel until ``_flush`` is called.
        ///
        /// The target descriptor is the fd the operation acts on (file, socket).
        /// It is borrowed — ownership remains with the caller. The backend
        /// extracts the raw fd at the syscall boundary.
        package let _submit: (
            Kernel.Completion.Submission,
            borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) -> Void

        /// Commit accumulated submissions to the kernel.
        ///
        /// Returns the count of submissions accepted. Backends that submit
        /// immediately (IOCP) return `.zero`.
        package let _flush: () throws(Kernel.Completion.Error) -> Submission.Count

        /// Drain available completion events, advancing the completion queue.
        ///
        /// Visits up to the currently available completion events in queue
        /// order, advancing the backend completion queue as events are
        /// delivered. The visitor receives each drained completion exactly
        /// once, in delivery order, and may not retain backend-owned storage.
        /// The visitor is non-throwing.
        ///
        /// Returns the count of completion entries consumed and delivered
        /// to the visitor.
        ///
        /// This is a post-notification drain — it processes whatever is in
        /// the completion queue at the time of the call. It does not block.
        ///
        /// The non-throwing contract is load-bearing: CQ advancement is a
        /// protocol action — partial drain corrupts ring state. If the visitor
        /// needs to propagate an error (e.g., continuation resolution failure),
        /// it stores the error in its dispatch table entry. The caller
        /// processes errors after drain returns.
        package let _drain: (
            (Kernel.Completion.Event) -> Void
        ) -> Event.Count

        /// Tear down the driver's internal backend state.
        ///
        /// Releases any resources owned through that state. Teardown is
        /// single-owner and occurs exactly once. Does not assert a specific
        /// descriptor/resource split — the factory determines what the
        /// state owns.
        package let _close: () -> Void

        /// Backend-supplied overflow counter query.
        ///
        /// Non-operational — separate from the four core operations.
        /// Returns `.zero` if the backend does not track overflow.
        package let _overflowCount: () -> Event.Count

        // MARK: - Init

        public init(
            submit: @escaping (Kernel.Completion.Submission, borrowing Kernel.Descriptor) throws(Kernel.Completion.Error) -> Void,
            flush: @escaping () throws(Kernel.Completion.Error) -> Submission.Count,
            drain: @escaping ((Kernel.Completion.Event) -> Void) -> Event.Count,
            close: @escaping () -> Void,
            overflowCount: @escaping () -> Event.Count = { .zero }
        ) {
            self._submit = submit
            self._flush = flush
            self._drain = drain
            self._close = close
            self._overflowCount = overflowCount
        }
    }
}


//
//  Kernel.Completion.swift
//  swift-kernel-primitives
//
//  ~Copyable resource owner for completion-based I/O notification.
//

// Wave 3.5-Final-Atomic (2026-05-02): explicit import for Kernel.Descriptor
// member access (Swift 6.x #MemberImportVisibility post-flip).
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
public import POSIX_Kernel_Descriptor
#endif

extension Kernel {
    /// Completion-based I/O notification resource.
    ///
    /// `~Copyable` — single ownership, consumed on ``close()``.
    /// NOT `Sendable` — transferred to the event loop thread via `sending`,
    /// then thread-confined. Extract ``wakeup`` (which IS `Sendable`)
    /// before the `sending` transfer for cross-thread signaling.
    ///
    /// ## Drain-After-Notification
    ///
    /// This is a drain-after-notification API, not a blocking wait API.
    /// The blocking wait belongs to the event loop. ``drain(_:)`` processes
    /// whatever is in the completion queue at the time of the call.
    ///
    /// ## Platform Backends
    ///
    /// - **Linux**: io_uring (submission/completion ring buffers)
    /// - **Windows**: IOCP (completion port) — future
    public struct Completion: ~Copyable {
        /// The operational witness (submit/flush/drain/close/overflowCount).
        package let driver: Driver

        /// Thread-safe channel for interrupting blocking waits.
        ///
        /// `Sendable` — extract before `sending` transfer for cross-thread
        /// wake signaling.
        public let wakeup: Kernel.Wakeup.Channel

        /// The notification descriptor, if the backend requires external
        /// event loop registration.
        ///
        /// Present for io_uring (eventfd for epoll). Absent for IOCP
        /// (which IS the notification mechanism). The event loop borrows
        /// ``Notification/descriptor`` for registration; raw fd extraction
        /// happens at the platform syscall boundary.
        public let notification: Notification?

        /// Backend capabilities for this completion instance.
        public let capabilities: Capabilities

        public init(
            driver: consuming Driver,
            wakeup: Kernel.Wakeup.Channel,
            notification: consuming Notification?,
            capabilities: Capabilities
        ) {
            self.driver = driver
            self.wakeup = wakeup
            self.notification = notification
            self.capabilities = capabilities
        }
    }
}

// MARK: - Public API

extension Kernel.Completion {
    /// Submit an operation targeting a descriptor.
    ///
    /// Enqueues the operation in the submission queue. The operation
    /// is not committed to the kernel until ``flush()`` is called.
    ///
    /// The target descriptor is the fd the operation acts on (file, socket).
    /// It is borrowed — ownership remains with the caller.
    public func submit(
        _ submission: Submission,
        target: borrowing Kernel.Descriptor
    ) throws(Error) {
        try driver._submit(submission, target)
    }

    /// Submit an untargeted operation (nop, cancel).
    ///
    /// Enqueues the operation in the submission queue. The operation
    /// is not committed to the kernel until ``flush()`` is called.
    public func submit(_ submission: Submission) throws(Error) {
        let sentinel = Kernel.Descriptor.invalid
        try driver._submit(submission, sentinel)
    }

    /// Commit accumulated submissions to the kernel.
    ///
    /// Returns the count of submissions accepted by the kernel.
    @discardableResult
    public func flush() throws(Error) -> Submission.Count {
        try driver._flush()
    }

    /// Drain available completion events.
    ///
    /// Visits up to the currently available completion events in queue
    /// order, advancing the backend completion queue as events are
    /// delivered. The visitor is non-throwing.
    ///
    /// Returns the count of completion entries consumed and delivered
    /// to the visitor.
    @discardableResult
    public func drain(
        _ visitor: (Event) -> Void
    ) -> Event.Count {
        driver._drain(visitor)
    }

    /// Cumulative count of completion events dropped due to queue overflow.
    ///
    /// Overflow indicates the consumer fell behind — the completion queue
    /// filled and the kernel dropped entries. This is queue health state,
    /// not per-event metadata. Read off the hot path for monitoring.
    public var overflowCount: Event.Count { driver._overflowCount() }

    /// Close the completion resource.
    ///
    /// Tears down driver state, then lets owned descriptors
    /// (notification, ring) deinit via `~Copyable` lifecycle.
    public consuming func close() {
        driver._close()
    }
}

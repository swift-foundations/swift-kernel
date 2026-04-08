//
//  Kernel.Completion.swift
//  swift-kernel
//
//  ~Copyable resource owner for completion-based I/O notification.
//
//  Owns the platform ring/port descriptor, wakeup channel,
//  and a Copyable Driver witness. Methods borrow self.descriptor
//  and pass to Driver closures.
//
//  Mirrors Kernel.Readiness for the proactor model:
//  - Readiness: register interest → poll for ready fds → do I/O
//  - Completion: submit operation → harvest completed operations
//

@_spi(Syscall) import Kernel_Primitives

extension Kernel {
    /// Completion-based I/O notification resource.
    ///
    /// `~Copyable`: single ownership, consumed on `close()`.
    /// Non-`Sendable`: thread-confined to the Loop's OS thread.
    /// Transfer to the Loop via `consuming sending`.
    ///
    /// The `Driver` inside is a pure Copyable witness (the recipe).
    /// `Completion` is the concrete resource (the thing).
    ///
    /// Platform backends:
    /// - **Linux**: io_uring (submission/completion ring buffers)
    /// - **Windows**: IOCP (completion port) — future
    ///
    /// ## Architecture
    ///
    /// Ring state (mmap'd pointers, SQ/CQ indices) is platform-specific
    /// and owned by the driver closures — not stored here.
    /// This struct owns only the kernel descriptor and the wakeup channel.
    /// Extract `wakeup` before transferring ownership to the Loop.
    ///
    /// ## Usage
    /// ```swift
    /// var completion = try Kernel.Completion.iouring(entries: 256)
    /// let wakeup = completion.wakeup  // extract before transfer
    /// try completion.submit(.nop, userData: 1)
    /// let flushed = try completion.flush()
    /// let count = try completion.harvest(into: &events)
    /// completion.close()
    /// ```
    public struct Completion: ~Copyable {
        /// The operational witness (submit/flush/harvest/drain + capabilities).
        public let driver: Driver

        /// The kernel descriptor (io_uring fd or IOCP handle).
        @_spi(Internal)
        public let descriptor: Kernel.Descriptor

        /// Thread-safe channel for interrupting blocking waits.
        // TODO: Extract Wakeup.Channel to Kernel.Wakeup.Channel (shared with Readiness)
        public let wakeup: Kernel.Readiness.Wakeup.Channel

        /// Backend capabilities.
        public var capabilities: Driver.Capabilities { driver.capabilities }

        @_spi(Internal)
        public init(
            driver: Driver,
            descriptor: consuming Kernel.Descriptor,
            wakeup: Kernel.Readiness.Wakeup.Channel
        ) {
            self.driver = driver
            self.descriptor = descriptor
            self.wakeup = wakeup
        }
    }
}

// MARK: - Public API

extension Kernel.Completion {
    /// Submit an operation for asynchronous execution.
    ///
    /// Enqueues the operation in the submission ring. The operation
    /// is not sent to the kernel until `flush()` is called.
    ///
    /// - Note: Caller must serialize access — this type is not internally synchronized.
    public func submit(
        _ submission: Submission
    ) throws(Error) {
        try driver._submit(descriptor, submission)
    }

    /// Flush accumulated submissions to the kernel.
    ///
    /// Calls `io_uring_enter` (Linux) or equivalent.
    /// Returns the number of submissions accepted by the kernel.
    @discardableResult
    public func flush() throws(Error) -> Int {
        try driver._flush(descriptor)
    }

    /// Harvest completed operations.
    ///
    /// On Linux: non-blocking (shared-memory CQ read, deadline ignored).
    /// On Windows: blocks until deadline or completions arrive.
    /// Returns the number of events harvested.
    ///
    /// - Note: Caller must serialize access — this type is not internally synchronized.
    public func harvest(
        deadline: Kernel.Time.Deadline? = nil,
        into events: inout [Event]
    ) throws(Error) -> Int {
        try driver._harvest(descriptor, deadline, &events)
    }

    /// Close the completion resource.
    ///
    /// Drains pending operations and lets the descriptor deinit close the fd.
    public consuming func close() {
        driver._drain(descriptor)
        // descriptor deinit closes the io_uring/IOCP fd
    }
}

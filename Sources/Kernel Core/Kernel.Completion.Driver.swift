//
//  Kernel.Completion.Driver.swift
//  swift-kernel
//
//  Pure Copyable witness for completion-based I/O operations.
//
//  The Driver is the recipe — four operational closures that know how
//  to talk to io_uring/IOCP, plus capabilities metadata.
//  Kernel.Completion is the thing — it owns the fd and calls the Driver.
//

@_spi(Syscall) import Kernel_Primitives

extension Kernel.Completion {
    /// Pure Copyable witness for completion backend operations.
    ///
    /// Contains four operational closures: submit, flush, harvest, drain.
    /// Does NOT own any resources — `Kernel.Completion` owns the fd.
    /// Ring state (mmap'd memory) is captured by the closures.
    ///
    /// Non-`Sendable`: thread-confined with the owning `Kernel.Completion`.
    /// The closures capture mmap'd ring state that is not thread-safe.
    ///
    /// The closures receive `borrowing Kernel.Descriptor` (the ring/port fd)
    /// as their first parameter. `Kernel.Completion` methods borrow
    /// `self.descriptor` and pass it to the Driver closures.
    public struct Driver {
        /// Backend capabilities.
        public let capabilities: Capabilities

        // MARK: - Operational Closures

        /// Enqueue a submission in the ring.
        ///
        /// Does NOT call the kernel — batches until `flush()`.
        public let _submit: (
            borrowing Kernel.Descriptor,
            Submission
        ) throws(Kernel.Completion.Error) -> Void

        /// Flush accumulated submissions to the kernel.
        ///
        /// Returns the number of submissions accepted.
        public let _flush: (
            borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) -> Int

        /// Harvest completed operations from the ring.
        ///
        /// On Linux (io_uring): non-blocking shared-memory CQ read.
        /// The deadline parameter is ignored — epoll_wait handles blocking.
        /// On Windows (IOCP): `GetQueuedCompletionStatusEx` with timeout.
        /// Returns the number of events harvested.
        public let _harvest: (
            borrowing Kernel.Descriptor,
            Kernel.Time.Deadline?,
            inout [Kernel.Completion.Event]
        ) throws(Kernel.Completion.Error) -> Int

        /// Driver-specific cleanup (unmap rings, drain pending).
        /// Does NOT close the fd — that's a resource-level concern
        /// handled by `Completion.close()`.
        public let _drain: (borrowing Kernel.Descriptor) -> Void

        // MARK: - Initializer

        public init(
            capabilities: Capabilities,
            submit: @escaping (borrowing Kernel.Descriptor, Submission) throws(Kernel.Completion.Error) -> Void,
            flush: @escaping (borrowing Kernel.Descriptor) throws(Kernel.Completion.Error) -> Int,
            harvest: @escaping (borrowing Kernel.Descriptor, Kernel.Time.Deadline?, inout [Kernel.Completion.Event]) throws(Kernel.Completion.Error) -> Int,
            drain: @escaping (borrowing Kernel.Descriptor) -> Void
        ) {
            self.capabilities = capabilities
            self._submit = submit
            self._flush = flush
            self._harvest = harvest
            self._drain = drain
        }
    }
}

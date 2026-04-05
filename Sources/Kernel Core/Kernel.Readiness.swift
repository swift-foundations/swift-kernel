//
//  Kernel.Readiness.swift
//  swift-kernel
//
//  ~Copyable resource owner for readiness-based event notification.
//
//  Owns the platform selector fd, scratch buffer, wakeup channel,
//  and a Copyable Driver witness. Methods borrow self.descriptor
//  and pass to Driver closures.
//

@_spi(Syscall) import Kernel_Primitives
public import Memory_Buffer_Primitives

extension Kernel {
    /// Readiness-based event notification resource.
    ///
    /// `~Copyable`: single ownership, consumed on `close()`.
    /// `Sendable`: safe to transfer to the poll thread.
    ///
    /// The `Driver` inside is a pure Copyable witness (the recipe).
    /// `Readiness` is the concrete resource (the thing).
    ///
    /// Platform backends:
    /// - **Darwin**: kqueue (`EVFILT_READ`, `EVFILT_WRITE`)
    /// - **Linux**: epoll (`EPOLLIN`, `EPOLLOUT`)
    ///
    /// ## Usage
    /// ```swift
    /// var readiness = try Kernel.Readiness.kqueue()
    /// let wakeup = readiness.wakeup  // Sendable copy
    /// let id = try readiness.register(descriptor: dup, interest: .read)
    /// let count = try readiness.poll(deadline: nil, into: &buffer)
    /// readiness.close()
    /// ```
    public struct Readiness: ~Copyable, Sendable {
        /// The operational witness (6 closures + drain + capabilities).
        public let driver: Driver

        /// The kernel descriptor (kqueue/epoll fd).
        @_spi(Internal)
        public let descriptor: Kernel.Descriptor

        /// Pre-allocated scratch buffer for raw kernel events.
        @_spi(Internal)
        public let buffer: Memory_Buffer_Primitives.Memory.Buffer.Mutable

        /// Thread-safe channel for interrupting blocking `poll()`.
        public let wakeup: Wakeup.Channel

        /// Backend capabilities.
        public var capabilities: Driver.Capabilities { driver.capabilities }

        @_spi(Internal)
        public init(
            driver: Driver,
            descriptor: consuming Kernel.Descriptor,
            buffer: Memory_Buffer_Primitives.Memory.Buffer.Mutable,
            wakeup: Wakeup.Channel
        ) {
            self.driver = driver
            self.descriptor = descriptor
            self.buffer = buffer
            self.wakeup = wakeup
        }
    }
}

// MARK: - Public API

extension Kernel.Readiness {
    /// Register a descriptor for the given interests.
    ///
    /// Takes `consuming` ownership of the dup'd descriptor.
    public func register(
        descriptor: consuming Kernel.Descriptor,
        interest: Kernel.Event.Interest
    ) throws(Error) -> Kernel.Event.ID {
        try driver._register(self.descriptor, descriptor, interest)
    }

    /// Modify the interests for a registered descriptor.
    public func modify(
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Error) {
        try driver._modify(descriptor, id, interest)
    }

    /// Remove a descriptor from the driver.
    public func deregister(
        id: Kernel.Event.ID
    ) throws(Error) {
        try driver._deregister(descriptor, id)
    }

    /// Re-arm a registration for readiness notification.
    public func arm(
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Error) {
        try driver._arm(descriptor, id, interest)
    }

    /// Wait for events with optional timeout.
    ///
    /// Blocks the calling thread.
    public func poll(
        deadline: Kernel.Time.Deadline?,
        into buffer: inout [Kernel.Event]
    ) throws(Error) -> Int {
        try driver._poll(descriptor, self.buffer, deadline, &buffer)
    }

    /// Close the readiness resource.
    ///
    /// Drains all registrations, deallocates the scratch buffer,
    /// and lets the descriptor deinit close the fd.
    public consuming func close() {
        driver._drain(descriptor)
        buffer.deallocate()
        // descriptor deinit closes the kqueue/epoll fd
    }
}

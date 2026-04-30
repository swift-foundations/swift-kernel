
//
//  Kernel.Event.Source.swift
//  swift-kernel-primitives
//
//  ~Copyable resource for event notification.
//


extension Kernel.Event {
    /// Event notification resource.
    ///
    /// `~Copyable`: single ownership, consumed on `close()`.
    /// Not `Sendable` — transferred to the poll thread via `sending`.
    /// Extract `wakeup` (Sendable) before transferring.
    ///
    /// ## Usage
    /// ```swift
    /// var source = try Kernel.Event.Source.platform()
    /// let wakeup = source.wakeup
    /// let id = try source.register(descriptor: dup, interest: .read)
    /// let count = try source.poll(deadline: nil, into: &buffer)
    /// source.close()
    /// ```
    public struct Source: ~Copyable {
        package let driver: Kernel.Event.Driver

        /// Thread-safe channel for interrupting blocking `poll()`.
        public let wakeup: Kernel.Wakeup.Channel

        public init(driver: consuming Kernel.Event.Driver, wakeup: Kernel.Wakeup.Channel) {
            self.driver = driver
            self.wakeup = wakeup
        }
    }
}

// MARK: - Public API

extension Kernel.Event.Source {
    public func register(
        descriptor: consuming Kernel.Descriptor,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Event.Driver.Error) -> Kernel.Event.ID {
        try driver._register(descriptor, interest)
    }

    public func modify(
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Event.Driver.Error) {
        try driver._modify(id, interest)
    }

    public func deregister(
        id: Kernel.Event.ID
    ) throws(Kernel.Event.Driver.Error) {
        try driver._deregister(id)
    }

    public func arm(
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Event.Driver.Error) {
        try driver._arm(id, interest)
    }

    public func poll(
        deadline: Clock.Continuous.Deadline?,
        into buffer: inout [Kernel.Event]
    ) throws(Kernel.Event.Driver.Error) -> Int {
        try driver._poll(deadline, &buffer)
    }

    public consuming func close() {
        driver._close()
    }
}


//
//  Kernel.Readiness.Driver.swift
//  swift-kernel
//
//  Single ~Copyable type for readiness-based event notification.
//
//  Owns the platform resource (kqueue/epoll fd + scratch buffer),
//  the Sendable wakeup channel, and six operational closures.
//  The "inert driver" model: stateful but threadless. The caller
//  supplies the thread that blocks in poll().
//

@_spi(Syscall) import Kernel_Primitives
public import Memory_Buffer_Primitives

extension Kernel.Readiness {
    /// Readiness driver owning a platform selector resource.
    ///
    /// `~Copyable`: single ownership, consumed on `close()`.
    /// `Sendable`: safe to transfer to the poll thread.
    ///
    /// ## Four-Part Contract
    ///
    /// 1. **Registration**: register/modify/deregister returning opaque tokens
    /// 2. **Waiting**: blocking poll invoked by caller-owned thread
    /// 3. **Wake**: wakeup channel for cross-thread interruption
    /// 4. **Normalization**: emit cross-platform `Kernel.Event` results
    ///
    /// ## Usage
    /// ```swift
    /// var driver = try Kernel.Readiness.Driver.kqueue()
    /// let wakeup = driver.wakeup  // Sendable copy
    /// let id = try driver.register(descriptor: dup, interest: .read)
    /// let count = try driver.poll(deadline: nil, into: &buffer)
    /// driver.close()
    /// ```
    public struct Driver: ~Copyable, Sendable {

        // MARK: - Owned Resources

        /// The kernel descriptor (kqueue/epoll fd).
        @_spi(Internal)
        public let descriptor: Kernel.Descriptor

        /// Pre-allocated scratch buffer for raw kernel events.
        @_spi(Internal)
        public let buffer: Memory.Buffer.Mutable

        /// Backend capabilities.
        public let capabilities: Capabilities

        /// Thread-safe channel for interrupting blocking `poll()`.
        public let wakeup: Kernel.Readiness.Wakeup.Channel

        // MARK: - Operational Closures

        let _register:
            @Sendable (
                borrowing Kernel.Descriptor,
                consuming Kernel.Descriptor,
                Kernel.Event.Interest
            ) throws(Error) -> Kernel.Event.ID

        let _modify:
            @Sendable (
                borrowing Kernel.Descriptor,
                Kernel.Event.ID,
                Kernel.Event.Interest
            ) throws(Error) -> Void

        let _deregister:
            @Sendable (
                borrowing Kernel.Descriptor,
                Kernel.Event.ID
            ) throws(Error) -> Void

        let _arm:
            @Sendable (
                borrowing Kernel.Descriptor,
                Kernel.Event.ID,
                Kernel.Event.Interest
            ) throws(Error) -> Void

        let _poll:
            @Sendable (
                borrowing Kernel.Descriptor,
                Memory.Buffer.Mutable,
                Kernel.Time.Deadline?,
                inout [Kernel.Event]
            ) throws(Error) -> Int

        let _close: @Sendable (consuming Kernel.Descriptor, Memory.Buffer.Mutable) -> Void

        // MARK: - Initializer

        @_spi(Internal)
        public init(
            descriptor: consuming Kernel.Descriptor,
            buffer: Memory.Buffer.Mutable,
            capabilities: Capabilities,
            wakeup: Kernel.Readiness.Wakeup.Channel,
            register: @escaping @Sendable (borrowing Kernel.Descriptor, consuming Kernel.Descriptor, Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID,
            modify: @escaping @Sendable (borrowing Kernel.Descriptor, Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void,
            deregister: @escaping @Sendable (borrowing Kernel.Descriptor, Kernel.Event.ID) throws(Error) -> Void,
            arm: @escaping @Sendable (borrowing Kernel.Descriptor, Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void,
            poll: @escaping @Sendable (borrowing Kernel.Descriptor, Memory.Buffer.Mutable, Kernel.Time.Deadline?, inout [Kernel.Event]) throws(Error) -> Int,
            close: @escaping @Sendable (consuming Kernel.Descriptor, Memory.Buffer.Mutable) -> Void
        ) {
            self.descriptor = descriptor
            self.buffer = buffer
            self.capabilities = capabilities
            self.wakeup = wakeup
            self._register = register
            self._modify = modify
            self._deregister = deregister
            self._arm = arm
            self._poll = poll
            self._close = close
        }
    }
}

// MARK: - Public API

extension Kernel.Readiness.Driver {
    /// Register a descriptor for the given interests.
    ///
    /// Takes `consuming` ownership of the dup'd descriptor.
    public func register(
        descriptor: consuming Kernel.Descriptor,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Readiness.Error) -> Kernel.Event.ID {
        try _register(self.descriptor, descriptor, interest)
    }

    /// Modify the interests for a registered descriptor.
    public func modify(
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Readiness.Error) {
        try _modify(descriptor, id, interest)
    }

    /// Remove a descriptor from the driver.
    public func deregister(
        id: Kernel.Event.ID
    ) throws(Kernel.Readiness.Error) {
        try _deregister(descriptor, id)
    }

    /// Re-arm a registration for readiness notification.
    public func arm(
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Readiness.Error) {
        try _arm(descriptor, id, interest)
    }

    /// Wait for events with optional timeout.
    ///
    /// Blocks the calling thread.
    public func poll(
        deadline: Kernel.Time.Deadline?,
        into buffer: inout [Kernel.Event]
    ) throws(Kernel.Readiness.Error) -> Int {
        try _poll(descriptor, self.buffer, deadline, &buffer)
    }

    /// Close the driver.
    ///
    /// Drains all registrations and releases resources.
    public consuming func close() {
        _close(descriptor, buffer)
    }
}

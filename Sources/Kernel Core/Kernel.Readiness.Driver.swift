//
//  Kernel.Readiness.Driver.swift
//  swift-kernel
//
//  Witness struct for platform-specific readiness backends.
//
//  The driver is an "inert facility": stateful (registry, IDs, staleness)
//  but threadless. The caller supplies the thread that blocks in poll().
//

extension Kernel.Readiness {
    /// Protocol witness struct for readiness-based event notification.
    ///
    /// ## Inert Driver Model
    ///
    /// The driver maintains state (registration table, ID generation,
    /// staleness tracking) but does not own threads. The caller supplies
    /// the thread that blocks in `poll()`.
    ///
    /// ## Four-Part Contract
    ///
    /// 1. **Registration**: register/modify/deregister returning opaque tokens
    /// 2. **Waiting**: blocking poll invoked by caller-owned thread
    /// 3. **Wake**: interrupt blocking wait for control-plane changes
    /// 4. **Normalization**: emit cross-platform `Kernel.Event` results
    ///
    /// ## Seven Policy Invariants
    ///
    /// All implementations must preserve:
    /// - INV-1: Registration Identity (unique non-zero IDs)
    /// - INV-2: Ownership Lifecycle (consuming dup, close on deregister)
    /// - INV-3: Delta Correctness (set-difference on modify)
    /// - INV-4: One-Shot Re-Arm (auto-disable after delivery)
    /// - INV-5: Normalization (cross-platform event format)
    /// - INV-6: Staleness Suppression (drop events for deregistered IDs)
    /// - INV-7: Wake Responsiveness (interrupt blocking poll)
    public struct Driver: Sendable {
        /// Backend capabilities.
        public let capabilities: Capabilities

        // MARK: - Witness Closures

        let _create: @Sendable () throws(Error) -> Handle

        let _register:
            @Sendable (
                borrowing Handle,
                consuming Kernel.Descriptor,
                Kernel.Event.Interest
            ) throws(Error) -> Kernel.Event.ID

        let _modify:
            @Sendable (
                borrowing Handle,
                Kernel.Event.ID,
                Kernel.Event.Interest
            ) throws(Error) -> Void

        let _deregister:
            @Sendable (
                borrowing Handle,
                Kernel.Event.ID
            ) throws(Error) -> Void

        let _arm:
            @Sendable (
                borrowing Handle,
                Kernel.Event.ID,
                Kernel.Event.Interest
            ) throws(Error) -> Void

        let _poll:
            @Sendable (
                borrowing Handle,
                Kernel.Time.Deadline?,
                inout [Kernel.Event]
            ) throws(Error) -> Int

        let _close: @Sendable (consuming Handle) -> Void

        let _wakeup: @Sendable (borrowing Handle) throws(Error) -> Kernel.Readiness.Wakeup

        // MARK: - Initializer

        public init(
            capabilities: Capabilities,
            create: @escaping @Sendable () throws(Error) -> Handle,
            register: @escaping @Sendable (borrowing Handle, consuming Kernel.Descriptor, Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID,
            modify: @escaping @Sendable (borrowing Handle, Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void,
            deregister: @escaping @Sendable (borrowing Handle, Kernel.Event.ID) throws(Error) -> Void,
            arm: @escaping @Sendable (borrowing Handle, Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void,
            poll: @escaping @Sendable (borrowing Handle, Kernel.Time.Deadline?, inout [Kernel.Event]) throws(Error) -> Int,
            close: @escaping @Sendable (consuming Handle) -> Void,
            wakeup: @escaping @Sendable (borrowing Handle) throws(Error) -> Kernel.Readiness.Wakeup
        ) {
            self.capabilities = capabilities
            self._create = create
            self._register = register
            self._modify = modify
            self._deregister = deregister
            self._arm = arm
            self._poll = poll
            self._close = close
            self._wakeup = wakeup
        }
    }
}

// MARK: - Public API

extension Kernel.Readiness.Driver {
    /// Create a new driver handle.
    public func create() throws(Kernel.Readiness.Error) -> Handle {
        try _create()
    }

    /// Register a descriptor for the given interests.
    ///
    /// Takes `consuming` ownership of the dup'd descriptor.
    public func register(
        _ handle: borrowing Handle,
        descriptor: consuming Kernel.Descriptor,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Readiness.Error) -> Kernel.Event.ID {
        try _register(handle, descriptor, interest)
    }

    /// Modify the interests for a registered descriptor.
    public func modify(
        _ handle: borrowing Handle,
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Readiness.Error) {
        try _modify(handle, id, interest)
    }

    /// Remove a descriptor from the driver.
    public func deregister(
        _ handle: borrowing Handle,
        id: Kernel.Event.ID
    ) throws(Kernel.Readiness.Error) {
        try _deregister(handle, id)
    }

    /// Re-arm a registration for readiness notification.
    ///
    /// After one-shot delivery, the filter is disabled.
    /// Call arm() to re-enable.
    public func arm(
        _ handle: borrowing Handle,
        id: Kernel.Event.ID,
        interest: Kernel.Event.Interest
    ) throws(Kernel.Readiness.Error) {
        try _arm(handle, id, interest)
    }

    /// Wait for events with optional timeout.
    ///
    /// Blocks the calling thread.
    public func poll(
        _ handle: borrowing Handle,
        deadline: Kernel.Time.Deadline?,
        into buffer: inout [Kernel.Event]
    ) throws(Kernel.Readiness.Error) -> Int {
        try _poll(handle, deadline, &buffer)
    }

    /// Close the driver handle.
    ///
    /// Drains all registrations and releases resources.
    public func close(_ handle: consuming Handle) {
        _close(handle)
    }

    /// Create a wakeup channel for this handle.
    ///
    /// The returned channel is `Sendable` and can interrupt blocking `poll()`.
    public func wakeup(_ handle: borrowing Handle) throws(Kernel.Readiness.Error) -> Kernel.Readiness.Wakeup {
        try _wakeup(handle)
    }
}

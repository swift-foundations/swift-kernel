//
//  Kernel.Readiness.Driver.swift
//  swift-kernel
//
//  Pure Copyable witness for readiness operations.
//
//  The Driver is the recipe — six operational closures that know how
//  to talk to kqueue/epoll, plus a drain closure for cleanup.
//  Kernel.Readiness is the thing — it owns the fd and calls the Driver.
//

@_spi(Syscall) import Kernel_Primitives
public import Memory_Buffer_Primitives

extension Kernel.Readiness {
    /// Pure Copyable witness for readiness backend operations.
    ///
    /// Contains six operational closures and a drain closure for cleanup.
    /// Does NOT own any resources — `Kernel.Readiness` owns the fd.
    ///
    /// The closures receive `borrowing Kernel.Descriptor` (the kqueue/epoll fd)
    /// as their first parameter. `Kernel.Readiness` methods borrow `self.descriptor`
    /// and pass it to the Driver closures.
    public struct Driver: Sendable {
        /// Backend capabilities.
        public let capabilities: Capabilities

        // MARK: - Operational Closures

        public let _register:
            @Sendable (
                borrowing Kernel.Descriptor,
                consuming Kernel.Descriptor,
                Kernel.Event.Interest
            ) throws(Kernel.Readiness.Error) -> Kernel.Event.ID

        public let _modify:
            @Sendable (
                borrowing Kernel.Descriptor,
                Kernel.Event.ID,
                Kernel.Event.Interest
            ) throws(Kernel.Readiness.Error) -> Void

        public let _deregister:
            @Sendable (
                borrowing Kernel.Descriptor,
                Kernel.Event.ID
            ) throws(Kernel.Readiness.Error) -> Void

        public let _arm:
            @Sendable (
                borrowing Kernel.Descriptor,
                Kernel.Event.ID,
                Kernel.Event.Interest
            ) throws(Kernel.Readiness.Error) -> Void

        public let _poll:
            @Sendable (
                borrowing Kernel.Descriptor,
                Memory.Buffer.Mutable,
                Kernel.Time.Deadline?,
                inout [Kernel.Event]
            ) throws(Kernel.Readiness.Error) -> Int

        /// Driver-specific cleanup (drain registry).
        /// Does NOT close the fd or deallocate the buffer —
        /// those are resource-level concerns handled by `Readiness.close()`.
        public let _drain: @Sendable (borrowing Kernel.Descriptor) -> Void

        // MARK: - Initializer

        public init(
            capabilities: Capabilities,
            register: @escaping @Sendable (borrowing Kernel.Descriptor, consuming Kernel.Descriptor, Kernel.Event.Interest) throws(Kernel.Readiness.Error) -> Kernel.Event.ID,
            modify: @escaping @Sendable (borrowing Kernel.Descriptor, Kernel.Event.ID, Kernel.Event.Interest) throws(Kernel.Readiness.Error) -> Void,
            deregister: @escaping @Sendable (borrowing Kernel.Descriptor, Kernel.Event.ID) throws(Kernel.Readiness.Error) -> Void,
            arm: @escaping @Sendable (borrowing Kernel.Descriptor, Kernel.Event.ID, Kernel.Event.Interest) throws(Kernel.Readiness.Error) -> Void,
            poll: @escaping @Sendable (borrowing Kernel.Descriptor, Memory.Buffer.Mutable, Kernel.Time.Deadline?, inout [Kernel.Event]) throws(Kernel.Readiness.Error) -> Int,
            drain: @escaping @Sendable (borrowing Kernel.Descriptor) -> Void
        ) {
            self.capabilities = capabilities
            self._register = register
            self._modify = modify
            self._deregister = deregister
            self._arm = arm
            self._poll = poll
            self._drain = drain
        }
    }
}

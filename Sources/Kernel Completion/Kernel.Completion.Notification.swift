//
//  Kernel.Completion.Notification.swift
//  swift-kernel
//
//  Notification handle for event loop integration.
//

extension Kernel.Completion {
    /// Notification handle for event loop integration.
    ///
    /// Owns a ``Kernel/Event/Descriptor`` (eventfd on Linux) with proper
    /// `~Copyable` lifecycle. The event loop borrows ``eventfd`` for
    /// platform registration (e.g., epoll). Raw fd extraction happens
    /// at the platform syscall boundary inside the event loop, not here.
    ///
    /// NOT `Sendable` — transferred as part of ``Completion`` via `sending`.
    ///
    /// Teardown: ``Completion/close()`` tears down driver state first
    /// (unmaps ring), then Notification's eventfd deinit closes the fd.
    ///
    /// Absent for backends where the completion mechanism IS the notification
    /// (IOCP).
    public struct Notification: ~Copyable {
        /// The eventfd descriptor for event loop integration.
        ///
        /// On Linux, registered with both io_uring (for completion signaling)
        /// and the event loop's poll mechanism (for notification delivery).
        public let eventfd: Kernel.Event.Descriptor

        package init(eventfd: consuming Kernel.Event.Descriptor) {
            self.eventfd = eventfd
        }
    }
}

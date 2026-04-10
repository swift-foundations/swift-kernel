//
//  Kernel.Completion.Notification.swift
//  swift-kernel
//
//  Notification handle for event loop integration.
//

extension Kernel.Completion {
    /// Notification handle for event loop integration.
    ///
    /// Owns the notification descriptor with proper `~Copyable` lifecycle.
    /// The event loop borrows the descriptor for platform registration
    /// (e.g., epoll); raw fd extraction happens at the platform syscall
    /// boundary.
    ///
    /// NOT `Sendable` — transferred as part of ``Completion`` via `sending`.
    ///
    /// Teardown: ``Completion/close()`` tears down driver state first
    /// (unmaps ring), then Notification's descriptor deinit closes the fd.
    ///
    /// Absent for backends where the completion mechanism IS the notification
    /// (IOCP).
    #if os(Linux)
    public struct Notification: ~Copyable {
        /// The eventfd descriptor for event loop integration.
        ///
        /// Registered with both io_uring (for completion signaling) and the
        /// event loop's poll mechanism (for notification delivery).
        public let eventfd: Kernel.Event.Descriptor

        package init(eventfd: consuming Kernel.Event.Descriptor) {
            self.eventfd = eventfd
        }
    }
    #else
    public struct Notification: ~Copyable {
        /// The notification descriptor for event loop integration.
        public let descriptor: Kernel.Descriptor

        package init(descriptor: consuming Kernel.Descriptor) {
            self.descriptor = descriptor
        }
    }
    #endif
}

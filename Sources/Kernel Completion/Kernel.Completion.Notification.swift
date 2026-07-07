//
//  Kernel.Completion.Notification.swift
//  swift-kernel-primitives
//
//  Notification handle for event loop integration.
//

// Wave 3.5-Final-Atomic (2026-05-02): explicit import for Kernel.Descriptor
// member access (Swift 6.x #MemberImportVisibility post-flip).
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public import POSIX_Kernel_Descriptor
#endif

extension Kernel.Completion {
    /// Notification handle for event loop integration.
    ///
    /// Owns the notification descriptor with proper `~Copyable` lifecycle.
    /// The event loop borrows the descriptor for platform registration
    /// (e.g., epoll); raw fd extraction happens at the platform syscall
    /// boundary.
    ///
    /// Backend-agnostic: the factory sets the appropriate descriptor
    /// (eventfd on Linux, platform-specific on others). Absent for
    /// backends where the completion mechanism IS the notification (IOCP).
    ///
    /// NOT `Sendable` — transferred as part of ``Completion`` via `sending`.
    ///
    /// Teardown: ``Completion/close()`` tears down driver state first
    /// (unmaps ring), then Notification's descriptor deinit closes the fd.
    public struct Notification: ~Copyable {
        /// The notification descriptor for event loop integration.
        public let descriptor: Kernel.Descriptor

        public init(descriptor: consuming Kernel.Descriptor) {
            self.descriptor = descriptor
        }
    }
}

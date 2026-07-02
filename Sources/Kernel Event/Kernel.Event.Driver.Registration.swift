
//
//  Kernel.Event.Driver.Registration.swift
//  swift-kernel-primitives
//
//  Backend-internal record for a registered event source.
//


// Windows: the event-driver vocabulary (Kernel.Event.Source: epoll/kqueue)
// is POSIX-only; the Windows analog is the IOCP completion path. Gated
// whole-file to match the IO Events / IO Completions posture — the Windows
// leg never constructs an event reactor.
#if !os(Windows)
extension Kernel.Event.Driver {
    /// A registration record owning a dup'd descriptor.
    ///
    /// `~Copyable`: the dup'd descriptor is closed when the
    /// entry is removed during deregister or shutdown.
    package struct Registration: ~Copyable, Sendable {
        package let descriptor: Kernel.Descriptor
        package var interest: Kernel.Event.Interest

        /// Interests currently armed with the kernel via one-shot delivery.
        ///
        /// Tracks the union of all pending arm requests so that backends
        /// with shared interest masks (epoll `EPOLL_CTL_MOD`) receive the
        /// combined mask. Updated by ``Driver/_arm`` (union on arm) and
        /// ``Driver/_poll`` (subtract delivered, re-arm residual).
        ///
        /// On backends with independent per-filter events (kqueue), the
        /// merge and re-arm are no-ops — re-enabling an already-enabled
        /// filter is harmless.
        package var armedInterest: Kernel.Event.Interest = []

        package init(descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) {
            self.descriptor = descriptor
            self.interest = interest
        }
    }
}
#endif

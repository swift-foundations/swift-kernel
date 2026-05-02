//
//  Kernel.Wakeup.Channel.swift
//  swift-kernel
//
//  Sendable handle that triggers a wakeup signal on a registered platform
//  primitive (eventfd on Linux, EVFILT_USER on Darwin). Constructed at
//  L3 site-of-use from a typed `@Sendable () -> Void` signal closure
//  produced by an L2 platform constructor (e.g., `epoll.wakeup(eventfd:)`,
//  `kqueue.wakeup()`).
//
//  Hosted at L3-unifier swift-kernel per [PLAT-ARCH-008c] / [PLAT-ARCH-008j]
//  (cross-platform vocabulary belongs at L3; raw fd capture stays at L2 inside
//  the signal closure). Relocated from iso-9945 L2 in Tier 5-Wakeup
//  (post-Path-X envelope, 2026-05-02).
//

extension Kernel.Wakeup {
    /// A Sendable handle for triggering a wakeup signal across threads.
    ///
    /// Wraps a `@Sendable () -> Void` signal closure produced by an L2
    /// platform constructor. The closure carries the raw platform handle
    /// (e.g., kqueue fd, eventfd) as a captured value, allowing the handle
    /// to outlive its owning ~Copyable struct's lexical scope while keeping
    /// `_rawValue` capture isolated at L2 per [PLAT-ARCH-008j].
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // L2 produces the signal closure
    /// let signal = try epoll.wakeup(eventfd: eventfd)
    ///
    /// // L3 wraps it for site-of-use
    /// let wakeup = Kernel.Wakeup.Channel(signal: signal)
    ///
    /// // Trigger from any thread
    /// wakeup.wake()
    /// ```
    public struct Channel: Sendable {
        private let signal: @Sendable () -> Void

        /// Creates a wakeup channel from a typed signal closure.
        ///
        /// - Parameter signal: A `@Sendable` closure that triggers the
        ///   underlying platform wakeup primitive when invoked.
        public init(signal: @escaping @Sendable () -> Void) {
            self.signal = signal
        }

        /// Triggers the wakeup signal.
        ///
        /// Safe to call from any thread. Causes the registered platform
        /// primitive to wake any blocked poll/wait operation.
        public func wake() {
            signal()
        }
    }
}

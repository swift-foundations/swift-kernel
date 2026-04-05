//
//  Kernel.Readiness.Wakeup.Channel.swift
//  swift-kernel
//
//  Thread-safe channel for interrupting blocking poll.
//

extension Kernel.Readiness.Wakeup {
    /// Thread-safe channel for waking the poll thread.
    ///
    /// Created by `driver.wakeup(handle)`. The channel is `Sendable`
    /// and can be called from any thread to interrupt a blocking `poll()`.
    ///
    /// Platform mechanism:
    /// - **kqueue**: `EVFILT_USER` trigger event
    /// - **epoll**: `eventfd` write
    public struct Channel: Sendable {
        private let signal: @Sendable () -> Void

        /// Creates a wakeup channel with the given signal closure.
        public init(signal: @escaping @Sendable () -> Void) {
            self.signal = signal
        }

        /// Interrupt a blocking `poll()` call.
        ///
        /// Thread-safe. Multiple concurrent calls are coalesced.
        /// Safe to call after the driver is closed (benign errors suppressed).
        public func wake() {
            signal()
        }
    }
}

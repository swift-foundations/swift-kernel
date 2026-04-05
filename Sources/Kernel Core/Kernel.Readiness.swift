//
//  Kernel.Readiness.swift
//  swift-kernel
//
//  Namespace for readiness-based (reactor) event notification.
//
//  Readiness drivers notify when a descriptor is ready for an I/O
//  operation. The consumer performs the actual I/O after notification.
//  Backed by kqueue (Darwin) and epoll (Linux).
//

extension Kernel {
    /// Readiness-based event notification.
    ///
    /// The readiness model (reactor pattern) notifies when a file descriptor
    /// is ready for I/O. The consumer then performs the actual read/write.
    ///
    /// Platform backends:
    /// - **Darwin**: kqueue (`EVFILT_READ`, `EVFILT_WRITE`)
    /// - **Linux**: epoll (`EPOLLIN`, `EPOLLOUT`)
    ///
    /// ## Usage
    /// ```swift
    /// var driver = try Kernel.Readiness.Backend.platformDefault()
    /// let wakeup = driver.wakeup  // Sendable copy
    /// let id = try driver.register(descriptor: dup, interest: .read)
    /// let count = try driver.poll(deadline: nil, into: &buffer)
    /// driver.close()
    /// ```
    public enum Readiness {}
}

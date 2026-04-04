//
//  Kernel.Readiness.Backend.swift
//  swift-kernel
//
//  Factory for platform-default readiness drivers.
//

extension Kernel.Readiness {
    /// Backend selection for readiness drivers.
    ///
    /// Provides factory methods that return the platform-appropriate driver.
    /// Consumer writes `Kernel.Readiness.Backend.platformDefault()` — no
    /// platform conditionals needed at the call site.
    public enum Backend {
        /// Returns the platform-default readiness driver.
        ///
        /// - **Darwin**: kqueue
        /// - **Linux**: epoll
        /// Returns the platform-default readiness driver.
        ///
        /// - **Darwin**: kqueue
        /// - **Linux**: epoll
        ///
        /// Implemented in Phase 2b when platform backends are added.
        public static func platformDefault() -> Kernel.Readiness.Driver {
            fatalError("Platform backends not yet implemented — see Phase 2b")
        }
    }
}

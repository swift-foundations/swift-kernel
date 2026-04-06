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
        public static func platformDefault() throws(Kernel.Readiness.Error) -> Kernel.Readiness {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
                try Kernel.Readiness.kqueue()
            #elseif os(Linux)
                try Kernel.Readiness.epoll()
            #else
                fatalError("No readiness backend available for this platform")
            #endif
        }
    }
}

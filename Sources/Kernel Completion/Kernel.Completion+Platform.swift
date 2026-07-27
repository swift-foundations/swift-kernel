//
//  Kernel.Completion+Platform.swift
//  swift-kernel
//
//  Platform factory for completion I/O.
//
//  The Completion struct, Driver, Submission, Event, and Error types
//  live in this same target. This file provides only the platform
//  factory that dispatches to backend-specific implementations.
//

// MARK: - Platform Default

extension Kernel.Completion {
    /// Returns the platform completion resource.
    ///
    /// - **Linux**: io_uring
    ///
    /// Throws ``Kernel/Completion/Error/unsupportedPlatform`` if no
    /// completion backend is available for the current platform (for
    /// example, on Darwin or on Linux without io_uring). Consumers that
    /// want graceful fallback to a reactor or blocking strategy can catch
    /// this via `try?` and select an alternative.
    public static func platform() throws(Error) -> Kernel.Completion {
        #if os(Linux)
            try .iouring()
        #else
            throw .unsupportedPlatform
        #endif
    }
}

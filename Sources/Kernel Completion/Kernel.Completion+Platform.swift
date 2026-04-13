//
//  Kernel.Completion+Platform.swift
//  swift-kernel
//
//  Platform factory for completion I/O.
//
//  The Completion struct, Driver, Submission, Event, and Error types
//  live at L1 (Kernel Completion Primitives). This file provides only
//  the platform factory that dispatches to backend-specific implementations.
//

// MARK: - Platform Default

extension Kernel.Completion {
    /// Returns the platform completion resource.
    ///
    /// - **Linux**: io_uring
    public static func platform() throws(Error) -> Kernel.Completion {
        #if os(Linux)
            try .iouring()
        #else
            fatalError("No completion backend available for this platform")
        #endif
    }
}

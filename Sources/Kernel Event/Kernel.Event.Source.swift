//
//  Kernel.Event.Source.swift
//  swift-kernel
//
//  Platform factory for event notification.
//
//  The Source struct, Driver, Registration, and Error types live at L1
//  (Kernel Event Primitives). This file provides only the platform
//  factory that dispatches to backend-specific implementations.
//

// MARK: - Platform Default

extension Kernel.Event.Source {
    /// Returns the platform event source.
    ///
    /// - **Darwin**: kqueue
    /// - **Linux**: epoll
    public static func platform() throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            try .kqueue()
        #elseif os(Linux)
            try .epoll()
        #else
            fatalError("No event backend available for this platform")
        #endif
    }
}

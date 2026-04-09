//
//  Kernel.Event.Driver.Error.swift
//  swift-kernel
//
//  Errors from readiness driver operations.
//

extension Kernel.Event.Driver {
    /// Errors from event driver operations.
    ///
    /// These are operational failures at the kernel boundary.
    /// Higher-level concerns (lifecycle, cancellation, half-close)
    /// are handled by the consuming layer (swift-io).
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Platform error code (POSIX errno).
        case platform(Kernel.Error.Code)

        /// The descriptor is invalid (closed, or driver not initialized).
        case invalidDescriptor

        /// The registration ID is not known to this driver.
        case notRegistered
    }
}

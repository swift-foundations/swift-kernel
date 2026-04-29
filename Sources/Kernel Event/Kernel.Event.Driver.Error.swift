//
//  Kernel.Event.Driver.Error.swift
//  swift-kernel-primitives
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
        case platform(Error_Primitives.Error.Code)

        /// The descriptor is invalid (closed, or driver not initialized).
        case invalidDescriptor

        /// The registration ID is not known to this driver.
        case notRegistered

        /// No event backend is available for the current platform.
        ///
        /// Thrown by ``Kernel/Event/Source/platform()`` on platforms where
        /// neither kqueue nor epoll (nor any future backend) is supported.
        /// Consumers that want graceful fallback to a blocking strategy
        /// can catch this via `try?` and select an alternative.
        case unsupportedPlatform
    }
}


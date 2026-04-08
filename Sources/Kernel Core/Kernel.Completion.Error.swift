//
//  Kernel.Completion.Error.swift
//  swift-kernel
//
//  Errors from completion driver operations.
//

extension Kernel.Completion {
    /// Errors from completion driver operations.
    ///
    /// Operational failures at the kernel boundary.
    /// Higher-level concerns (cancellation, timeout, lifecycle)
    /// are handled by the consuming layer (swift-io).
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Platform error code (POSIX errno).
        case platform(Kernel.Error.Code)

        /// The submission ring is full — flush before submitting more.
        case submissionQueueFull

        /// The ring descriptor is invalid (closed, or driver not initialized).
        case invalidDescriptor
    }
}

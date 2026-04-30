//
//  Kernel.Completion.Error.swift
//  swift-kernel-primitives
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
        case platform(Error_Primitives.Error.Code)

        /// The submission ring is full — flush before submitting more.
        case submissionQueueFull

        /// The ring descriptor is invalid (closed, or driver not initialized).
        case invalidDescriptor

        /// No completion backend is available for the current platform.
        ///
        /// Thrown by ``Kernel/Completion/platform()`` on platforms where
        /// neither io_uring (nor any future backend such as IOCP) is
        /// supported. Consumers that want graceful fallback to a reactor
        /// or blocking strategy can catch this via `try?` and select an
        /// alternative.
        case unsupportedPlatform
    }
}

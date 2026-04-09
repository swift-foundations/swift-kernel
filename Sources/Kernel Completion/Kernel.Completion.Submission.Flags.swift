//
//  Kernel.Completion.Submission.Flags.swift
//  swift-kernel
//
//  Platform-agnostic submission flags.
//
//  The consumer sets intent via typed flags. The driver backend
//  maps to platform-specific flag values (io_uring IOSQE_*,
//  IOCP OVERLAPPED flags).
//

extension Kernel.Completion.Submission {
    /// Flags controlling submission behavior.
    ///
    /// These express platform-agnostic intent. The driver backend
    /// maps each flag to the platform-specific value.
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// Select a buffer from the specified buffer group at completion time.
        ///
        /// io_uring: `IOSQE_BUFFER_SELECT`. Requires `bufferGroup` to be set.
        /// Used with multishot recv for kernel-managed buffer pools.
        public static let bufferSelect = Flags(rawValue: 1 << 0)

        /// Link this operation to the next submission.
        ///
        /// io_uring: `IOSQE_IO_LINK`. The next submission executes only
        /// after this one completes successfully. Failure cancels the chain.
        public static let linked = Flags(rawValue: 1 << 1)

        /// Drain the submission queue before executing this operation.
        ///
        /// io_uring: `IOSQE_IO_DRAIN`. Ensures all prior submissions
        /// complete before this one begins. Serialization barrier.
        public static let drain = Flags(rawValue: 1 << 2)

        /// Use a registered (fixed) file descriptor.
        ///
        /// io_uring: `IOSQE_FIXED_FILE`. Required for SQPOLL mode.
        /// The target descriptor must be pre-registered with the ring.
        public static let fixedFile = Flags(rawValue: 1 << 3)
    }
}

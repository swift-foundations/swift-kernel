//
//  Kernel.Completion.Event.swift
//  swift-kernel
//
//  Raw completion event from the kernel ring.
//
//  Platform-agnostic value type. The consuming layer (swift-io)
//  interprets userData to match continuations and result to
//  determine success/failure.
//

extension Kernel.Completion {
    /// A raw completion event harvested from the kernel.
    ///
    /// Copyable value type — no owned resources at this layer.
    /// The IO layer wraps this into richer types with outcome
    /// enums and ~Copyable descriptor transfer.
    public struct Event: Sendable {
        /// Matches the submission's userData — used by the consumer
        /// to correlate completions with in-flight operations.
        public let userData: UInt64

        /// Operation result.
        ///
        /// Interpretation depends on the operation:
        /// - read/write/send/recv: bytes transferred (positive) or negative errno
        /// - accept: new file descriptor (positive) or negative errno
        /// - nop/close: 0 on success, negative errno on failure
        public let result: Int32

        /// Platform-specific completion flags.
        ///
        /// - io_uring: `IORING_CQE_F_MORE`, `IORING_CQE_F_BUFFER`, etc.
        /// - IOCP: unused (0)
        public let flags: UInt32

        public init(userData: UInt64, result: Int32, flags: UInt32 = 0) {
            self.userData = userData
            self.result = result
            self.flags = flags
        }
    }
}

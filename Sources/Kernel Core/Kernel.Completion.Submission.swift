//
//  Kernel.Completion.Submission.swift
//  swift-kernel
//
//  Flat operation descriptor for the submission ring.
//
//  The consumer (IO.Event.Loop) constructs a Submission from
//  its typed operation and passes it to the driver. The driver
//  translates it into platform-specific SQE/function calls.
//

extension Kernel.Completion {
    /// A submission to enqueue in the completion ring.
    ///
    /// Flat struct that maps naturally to io_uring SQE fields.
    /// The driver backend translates opcode → platform opcode
    /// and fills the platform-specific entry.
    public struct Submission: Sendable {
        /// What operation to perform.
        public var opcode: Opcode

        /// Target file descriptor (raw value).
        ///
        /// Set by the consuming layer via `_rawValue` extraction.
        /// -1 for operations without a target fd (nop, cancel).
        public var fd: Int32

        /// Correlation token — returned in the completion event.
        public var userData: UInt64

        /// Buffer address (for read/write/send/recv).
        public var addr: UInt64

        /// Buffer length (for read/write/send/recv).
        public var length: UInt32

        /// File offset (for positioned read/write). 0 for stream operations.
        public var offset: UInt64

        /// Platform-specific SQE flags.
        public var sqeFlags: UInt32

        /// Buffer group ID for provided buffer selection.
        ///
        /// Used with multishot recv (IOSQE_BUFFER_SELECT) where the
        /// kernel selects a buffer from the pool at completion time.
        /// 0 when not using provided buffers.
        public var bufferGroup: UInt16

        public init(opcode: Opcode, fd: Int32 = -1, userData: UInt64) {
            self.opcode = opcode
            self.fd = fd
            self.userData = userData
            self.addr = 0
            self.length = 0
            self.offset = 0
            self.sqeFlags = 0
            self.bufferGroup = 0
        }
    }
}

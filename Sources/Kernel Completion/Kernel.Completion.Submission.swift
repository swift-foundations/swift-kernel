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
    /// Pure operation description — says *what* to do, not *what to do it to*.
    /// The target descriptor is passed separately via `borrowing Kernel.Descriptor`
    /// at the submit call site.
    ///
    /// The driver backend translates opcode → platform opcode
    /// and fills the platform-specific entry.
    public struct Submission: Sendable {
        /// What operation to perform.
        public var opcode: Opcode

        /// Correlation token — returned in the completion event.
        public var token: Token

        /// Buffer address (for read/write/send/recv).
        public var address: Address

        /// Buffer length (for read/write/send/recv).
        public var length: Length

        /// File offset (for positioned read/write).
        public var offset: Offset

        /// Platform-agnostic submission flags.
        public var flags: Flags

        /// Buffer group ID for provided buffer selection.
        ///
        /// Used with multishot recv where the kernel selects a buffer
        /// from the pool at completion time.
        public var bufferGroup: Buffer.Group

        public init(
            opcode: Opcode,
            token: Token,
            address: Address = .none,
            length: Length = .zero,
            offset: Offset = .zero,
            flags: Flags = [],
            bufferGroup: Buffer.Group = .none
        ) {
            self.opcode = opcode
            self.token = token
            self.address = address
            self.length = length
            self.offset = offset
            self.flags = flags
            self.bufferGroup = bufferGroup
        }
    }
}

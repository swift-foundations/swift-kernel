//
//  Kernel.Completion.Submission.swift
//  swift-kernel-primitives
//
//  Flat operation descriptor for the submission ring.
//
//  Non-variant fields (correlation token, submission flags, buffer
//  group) live as struct fields. Variant data lives in `opcode`'s
//  associated values — unrepresentable for opcodes that don't use it.
//

extension Kernel.Completion {
    /// A submission to enqueue in the completion ring.
    ///
    /// The target descriptor is passed separately via `borrowing
    /// Kernel.Descriptor` at the submit call site; the backend fills
    /// the platform-specific submission entry from `opcode`'s
    /// associated values and the target.
    public struct Submission: Sendable {
        /// Correlation token — returned in the matching completion event.
        public var token: Token

        /// Operation descriptor — carries per-variant data as associated
        /// values.
        public var opcode: Opcode

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
            flags: Flags = [],
            bufferGroup: Buffer.Group = .none
        ) {
            self.token = token
            self.opcode = opcode
            self.flags = flags
            self.bufferGroup = bufferGroup
        }
    }
}

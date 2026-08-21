extension Kernel.Completion {

    public struct Submission: Sendable {

        public var token: Token

        public var opcode: Opcode

        public var flags: Flags

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

extension Kernel.Completion {

    public struct Event: Sendable {

        public let token: Kernel.Completion.Token

        public let result: Kernel.Completion.Event.Result

        public let flags: Kernel.Completion.Event.Flags

        public init(
            token: Kernel.Completion.Token,
            result: Kernel.Completion.Event.Result,
            flags: Kernel.Completion.Event.Flags = []
        ) {
            self.token = token
            self.result = result
            self.flags = flags
        }
    }
}

extension Kernel.Completion {

    public struct Capabilities: Sendable {

        public let multishot: Bool

        public let providedBuffers: Bool

        public init(
            multishot: Bool = false,
            providedBuffers: Bool = false
        ) {
            self.multishot = multishot
            self.providedBuffers = providedBuffers
        }
    }
}

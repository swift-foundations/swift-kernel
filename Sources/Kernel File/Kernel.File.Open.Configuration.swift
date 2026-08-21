extension Kernel.File.Open {

    public struct Configuration: Sendable, Equatable {

        public var mode: Kernel.File.Open.Mode

        public var create: Bool

        public var truncate: Bool

        public var cache: Kernel.File.Direct.Mode

        public init() {
            self.mode = .read
            self.create = false
            self.truncate = false
            self.cache = .buffered
        }

        public init(mode: Kernel.File.Open.Mode) {
            self.mode = mode
            self.create = false
            self.truncate = false
            self.cache = .buffered
        }
    }
}

extension Kernel.Completion.Event {

    public struct Result: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Completion.Event.Result {

    public var isSuccess: Bool { rawValue >= 0 }

    public var value: Int32? {
        isSuccess ? rawValue : nil
    }
}

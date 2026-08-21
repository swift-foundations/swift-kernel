extension Kernel.Completion.Event {

    public struct Flags: OptionSet, Sendable, Hashable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Completion.Event.Flags {

    public static let more = Self(rawValue: 1 << 0)
}

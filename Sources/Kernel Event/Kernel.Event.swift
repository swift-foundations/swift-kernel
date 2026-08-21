extension Kernel {

    public struct Event: Sendable, Equatable {

        public let id: ID

        public let interest: Interest

        public let flags: Options

        public init(id: ID, interest: Interest, flags: Options = []) {
            self.id = id
            self.interest = interest
            self.flags = flags
        }
    }
}

extension Kernel.Event {

    public static let empty = Self(id: .zero, interest: [], flags: [])
}

extension Kernel.Event: CustomStringConvertible {
    public var description: Swift.String {
        var parts = ["Event(id: \(id), interest: \(interest)"]
        if !flags.isEmpty {
            parts.append(", flags: \(flags)")
        }
        return parts.joined() + ")"
    }
}

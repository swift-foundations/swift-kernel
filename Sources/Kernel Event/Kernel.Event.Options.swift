extension Kernel.Event {

    public struct Options: OptionSet, Sendable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

extension Kernel.Event.Options {

    public static let error = Self(rawValue: 1 << 0)

    public static let hangup = Self(rawValue: 1 << 1)

    public static let readHangup = Self(rawValue: 1 << 2)

    public static let writeHangup = Self(rawValue: 1 << 3)
}

extension Kernel.Event.Options: CustomStringConvertible {
    public var description: Swift.String {
        var parts: [Swift.String] = []
        if contains(.error) { parts.append("error") }
        if contains(.hangup) { parts.append("hangup") }
        if contains(.readHangup) { parts.append("readHangup") }
        if contains(.writeHangup) { parts.append("writeHangup") }
        return parts.isEmpty ? "none" : parts.joined(separator: "|")
    }
}

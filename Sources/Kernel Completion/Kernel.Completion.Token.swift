public import Tagged_Primitives

extension Kernel.Completion {

    public typealias Token = Tagged<Kernel.Completion, UInt64>
}

extension Kernel.Completion.Token {

    public init(_ identifier: UInt64) {
        self = Self(_unchecked: identifier)
    }

    public static let zero = Self(_unchecked: 0)
}

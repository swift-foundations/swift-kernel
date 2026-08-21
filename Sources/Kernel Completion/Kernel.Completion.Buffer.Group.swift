public import Tagged_Primitives

extension Kernel.Completion.Buffer {

    public typealias Group = Tagged<Kernel.Completion.Buffer, UInt16>
}

extension Kernel.Completion.Buffer.Group {

    public init(_ id: UInt16) {
        self = Self(_unchecked: id)
    }

    public static let none = Self(_unchecked: 0)
}

public import Tagged_Primitives

extension Kernel.Event {

    public typealias ID = Tagged<Kernel.Event, UInt>
}

extension Tagged where Tag == Kernel.Event, Underlying == UInt {

    @inlinable
    public init(_ value: Int32) {
        self.init(_unchecked: UInt(bitPattern: Int(value)))
    }
}

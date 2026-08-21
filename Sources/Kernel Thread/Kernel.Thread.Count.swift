extension Kernel.Thread {

    public typealias Count = Tagged<Kernel.Thread, Cardinal>
}

extension Kernel.Thread.Count {

    @inlinable
    public init(_ processorCount: System.Processor.Count) {
        self = processorCount.retag(Kernel.Thread.self)
    }
}

extension Int {

    @inlinable
    public init(_ count: Kernel.Thread.Count) {
        self = Int(bitPattern: count)
    }
}

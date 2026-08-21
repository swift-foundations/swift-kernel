extension Tagged where Underlying == CPU.Atomic.Flag, Tag: ~Copyable & ~Escapable {

    @inlinable
    public var isSet: Bool { underlying.isSet }

    @inlinable
    public func set() { underlying.set() }
}

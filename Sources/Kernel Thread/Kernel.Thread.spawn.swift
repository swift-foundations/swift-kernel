extension Kernel.Thread {

    public struct Spawn: Sendable {
        @usableFromInline
        init() {}
    }

    public static var spawn: Spawn { Spawn() }
}

extension Kernel.Thread.Spawn {

    @inlinable
    public func callAsFunction(
        _ body: @escaping @Sendable () -> Void
    ) throws(Kernel.Thread.Error) -> Kernel.Thread.Handle {
        try Kernel.Thread.create(body)
    }

    @inlinable
    public func callAsFunction<T: ~Copyable>(
        _ value: consuming sending T,
        _ body: @escaping @Sendable (consuming T) -> Void
    ) throws(Kernel.Thread.Error) -> Kernel.Thread.Handle {

        let cell = Ownership.Transfer.Value<T>.Outgoing(value)
        let token = cell.token()

        return try self {
            let v = token.take()
            body(v)
        }
    }
}

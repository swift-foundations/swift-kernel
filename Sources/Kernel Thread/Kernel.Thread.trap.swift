extension Kernel.Thread {

    public struct Trap: Sendable {
        @usableFromInline
        init() {}
    }

    public static var trap: Trap { Trap() }
}

extension Kernel.Thread.Trap {

    @inlinable
    public func callAsFunction(
        _ body: @escaping @Sendable () -> Void
    ) -> Kernel.Thread.Handle {
        do throws(Kernel.Thread.Error) { return try Kernel.Thread.spawn(body) } catch {
            fatalError(error.description)
        }
    }

    @inlinable
    public func callAsFunction<T: ~Copyable>(
        _ value: consuming sending T,
        _ body: @escaping @Sendable (consuming T) -> Void
    ) -> Kernel.Thread.Handle {
        do throws(Kernel.Thread.Error) { return try Kernel.Thread.spawn(value, body) } catch {
            fatalError(error.description)
        }
    }
}

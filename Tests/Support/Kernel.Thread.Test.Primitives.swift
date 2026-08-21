import Kernel

public final class LockedBox<T>: @unchecked Sendable {
    private var value: T
    private let lock: Kernel.Thread.Mutex

    public init(_ initial: T) {
        self.value = initial
        self.lock = .init()
    }

    public func withLock<R>(_ body: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

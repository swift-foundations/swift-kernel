import Kernel

public enum KernelThreadTest {

    public struct Timeout: Swift.Error, Sendable, Equatable {
        public init() {}
    }

    public final class Harness<State>: @unchecked Sendable {
        private let mutex: Kernel.Thread.Mutex
        private let condition: Kernel.Thread.Condition
        private var state: State

        public init(_ initial: State) {
            self.mutex = Kernel.Thread.Mutex()
            self.condition = Kernel.Thread.Condition()
            self.state = initial
        }

        public func withLocked<R>(_ body: (inout State) -> R) -> R {
            mutex.lock()
            defer { mutex.unlock() }
            return body(&state)
        }

        public func update(_ body: (inout State) -> Void) {
            mutex.lock()
            body(&state)
            condition.broadcast()
            mutex.unlock()
        }

        public func signal() {
            mutex.lock()
            condition.broadcast()
            mutex.unlock()
        }

        public func wait(
            until predicate: (State) -> Bool,
            timeoutSeconds: Int = 5
        ) throws(Timeout) {
            mutex.lock()
            defer { mutex.unlock() }

            if predicate(state) { return }

            let timeout = Duration.seconds(timeoutSeconds)

            while !predicate(state) {
                let signaled = condition.wait(mutex: mutex, timeout: timeout)
                if !signaled { throw Timeout() }
            }
        }
    }
}

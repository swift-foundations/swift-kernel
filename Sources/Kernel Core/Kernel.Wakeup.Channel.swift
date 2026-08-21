extension Kernel.Wakeup {

    public struct Channel: Sendable {
        private let signal: @Sendable () -> Void

        public init(signal: @escaping @Sendable () -> Void) {
            self.signal = signal
        }
    }
}

extension Kernel.Wakeup.Channel {

    public func wake() {
        signal()
    }
}

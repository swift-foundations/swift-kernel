#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public import POSIX_Kernel_Descriptor
#endif

extension Kernel {

    public struct Completion: ~Copyable {

        package let driver: Driver

        public let wakeup: Kernel.Wakeup.Channel

        public let notification: Notification?

        public let capabilities: Capabilities

        public init(
            driver: consuming Driver,
            wakeup: Kernel.Wakeup.Channel,
            notification: consuming Notification?,
            capabilities: Capabilities
        ) {
            self.driver = driver
            self.wakeup = wakeup
            self.notification = notification
            self.capabilities = capabilities
        }
    }
}

extension Kernel.Completion {

    public func submit(
        _ submission: Submission,
        target: borrowing Kernel.Descriptor
    ) throws(Error) {
        try driver._submit(submission, target)
    }

    public func submit(_ submission: Submission) throws(Error) {
        let sentinel = Kernel.Descriptor.invalid
        try driver._submit(submission, sentinel)
    }

    @discardableResult
    public func flush() throws(Error) -> Submission.Count {
        try driver._flush()
    }

    @discardableResult
    public func drain(
        _ visitor: (Event) -> Void
    ) -> Event.Count {
        driver._drain(visitor)
    }

    public var overflowCount: Event.Count { driver._overflowCount() }

    public consuming func close() {
        driver._close()
    }
}

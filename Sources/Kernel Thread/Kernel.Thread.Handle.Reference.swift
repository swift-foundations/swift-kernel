extension Kernel.Thread.Handle {

    public final class Reference: @unchecked Sendable {
        private var inner: Kernel.Thread.Handle?

        public init(_ handle: consuming Kernel.Thread.Handle) {
            self.inner = consume handle
        }

        deinit {

            precondition(
                inner == nil,
                "Kernel.Thread.Handle.Reference deallocated without join()"
            )
        }
    }
}

extension Kernel.Thread.Handle.Reference {

    public func join() throws(Kernel.Thread.Error) {
        guard let handle = inner.take() else {
            preconditionFailure(
                "Kernel.Thread.Handle.Reference.join() called twice"
            )
        }
        try handle.join()
    }
}

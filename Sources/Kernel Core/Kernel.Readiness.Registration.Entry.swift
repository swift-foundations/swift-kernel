//
//  Kernel.Readiness.Registration.Entry.swift
//  swift-kernel
//
//  A poll-thread-side registration entry owning a dup'd descriptor.
//

extension Kernel.Readiness.Registration {
    /// A registration entry owning a dup'd descriptor.
    ///
    /// `~Copyable` prevents aliasing. The dup'd descriptor is closed
    /// when the entry is removed during deregister or shutdown.
    public struct Entry: ~Copyable, Sendable {
        /// The dup'd descriptor owned by the driver.
        public let descriptor: Kernel.Descriptor
        /// The currently registered interest set.
        public var interest: Kernel.Event.Interest

        public init(descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) {
            self.descriptor = descriptor
            self.interest = interest
        }
    }
}

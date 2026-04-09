//
//  Kernel.Event.Driver.Registration.swift
//  swift-kernel
//
//  Backend-internal record for a registered event source.
//

extension Kernel.Event.Driver {
    /// A registration record owning a dup'd descriptor.
    ///
    /// `~Copyable`: the dup'd descriptor is closed when the
    /// entry is removed during deregister or shutdown.
    package struct Registration: ~Copyable, Sendable {
        package let descriptor: Kernel.Descriptor
        package var interest: Kernel.Event.Interest

        package init(descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) {
            self.descriptor = descriptor
            self.interest = interest
        }
    }
}

#if !os(Windows)
    extension Kernel.Event.Driver {

        package struct Registration: ~Copyable, Sendable {
            package let descriptor: Kernel.Descriptor
            package var interest: Kernel.Event.Interest

            package var armedInterest: Kernel.Event.Interest = []

            package init(descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) {
                self.descriptor = descriptor
                self.interest = interest
            }
        }
    }
#endif

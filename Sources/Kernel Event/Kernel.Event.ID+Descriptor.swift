#if !os(Windows)
    @_spi(Internal) import Tagged_Primitives
    @_spi(Syscall) public import POSIX_Kernel_Descriptor

    extension Tagged where Tag == Kernel.Event, Underlying == UInt {

        public init(descriptor: borrowing Kernel.Descriptor) {

            self.init(_unchecked: UInt(bitPattern: Int(descriptor._rawValue)))
        }
    }

#endif

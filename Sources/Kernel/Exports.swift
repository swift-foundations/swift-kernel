@_exported public import Kernel_Clock
@_exported public import Kernel_Completion
@_exported public import Kernel_Core
@_exported public import Kernel_Event
@_exported public import Kernel_File
@_exported public import Kernel_System
@_exported public import Kernel_Thread

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public typealias Kernel = POSIX.Kernel
#elseif os(Windows)
    public typealias Kernel = Windows.Kernel
#endif

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel_Descriptor
    @_exported public import POSIX_Kernel_Directory

    extension Kernel {

        public typealias Descriptor = POSIX.Kernel.Descriptor
    }
#elseif os(Windows)
    @_exported public import Windows_Kernel_Descriptor

    extension Kernel {

        public typealias Descriptor = Windows.Kernel.Descriptor
    }
#endif

#if !os(Windows)
    extension Kernel.Descriptor {
        public typealias Interest = Kernel.Event.Interest
    }
#endif

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel_Socket

    extension Kernel.Socket {

        public typealias Descriptor = POSIX.Kernel.Socket.Descriptor
    }
#elseif os(Windows)
    @_exported public import Windows_Kernel_Socket

    extension Kernel.Socket {

        public typealias Descriptor = Windows.Kernel.Socket.Descriptor
    }
#endif

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel_Lock
#elseif os(Windows)
    @_exported public import Windows_Kernel_Lock
#endif

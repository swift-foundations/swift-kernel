@_exported public import Clock_Primitives

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD)
    @_exported public import POSIX_Kernel_Clock
#elseif os(Windows)
    @_exported public import Windows_Kernel_Clock
#endif

//
//  Kernel.Readiness.Driver.Handle.swift
//  swift-kernel
//
//  Opaque, platform-specific handle for a readiness driver instance.
//

@_spi(Syscall) import Kernel_Primitives

extension Kernel.Readiness.Driver {
    /// Opaque handle for a readiness driver instance.
    ///
    /// `~Copyable`: single ownership, consumed on close.
    /// Owned by the poll thread for its entire lifetime.
    ///
    /// `@unchecked Sendable`: the buffer pointer is only accessed
    /// from the poll thread. Single ownership via `~Copyable` prevents
    /// aliasing.
    public struct Handle: ~Copyable, @unchecked Sendable {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            /// The kernel descriptor owning the kqueue/epoll fd.
            @usableFromInline
            package let descriptor: Kernel.Descriptor

            /// Pre-allocated scratch buffer for raw kernel events.
            /// Allocated as raw bytes, rebound to platform event type during poll.
            @usableFromInline
            package let buffer: UnsafeMutableRawBufferPointer

            @usableFromInline
            package init(descriptor: consuming Kernel.Descriptor, buffer: UnsafeMutableRawBufferPointer) {
                self.descriptor = descriptor
                self.buffer = buffer
            }

            /// Raw fd value for registry keying.
            @_spi(Syscall)
            @usableFromInline
            package var rawValue: Int32 { descriptor._rawValue }
        #endif
    }
}

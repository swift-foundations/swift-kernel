//
//  Kernel.Readiness.Driver.Handle.swift
//  swift-kernel
//
//  Opaque, platform-specific handle for a readiness driver instance.
//

@_spi(Syscall) import Kernel_Primitives
public import Memory_Buffer_Primitives

extension Kernel.Readiness.Driver {
    /// Opaque handle for a readiness driver instance.
    ///
    /// `~Copyable`: single ownership, consumed on close.
    /// Owned by the poll thread for its entire lifetime.
    ///
    /// ## Platform Storage
    /// - **Darwin**: kqueue fd + raw event scratch buffer
    /// - **Linux**: epoll fd + raw event scratch buffer
    public struct Handle: ~Copyable, Sendable {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            /// The kernel descriptor owning the kqueue/epoll fd.
            @usableFromInline
            package let descriptor: Kernel.Descriptor

            /// Pre-allocated scratch buffer for raw kernel events.
            /// Content is typed via `withRebound` in platform poll implementations.
            @usableFromInline
            package let buffer: Memory.Buffer.Mutable

            @usableFromInline
            package init(descriptor: consuming Kernel.Descriptor, buffer: Memory.Buffer.Mutable) {
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

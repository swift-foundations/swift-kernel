// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel.Thread {
    /// Per-thread typed storage slot for a class-typed payload.
    ///
    /// L3 cross-platform unifier over the platform's TLS family:
    /// - POSIX: `pthread_key_create` / `pthread_setspecific` / etc., via
    ///   ``ISO_9945/Kernel/Thread/Key``.
    /// - Windows: `TlsAlloc` / `TlsSetValue` / etc., via
    ///   ``Windows/Kernel/Thread/Index``.
    ///
    /// Owns one platform-allocated TLS slot and stores a retained
    /// `Payload?` reference per thread. The `Unmanaged` retain/release
    /// dance is encapsulated inside the slot's `value` accessor so call
    /// sites see only the safe `Payload?` surface.
    ///
    /// Per [PLAT-ARCH-008f] solution (a), the L2 raw classes use spec-
    /// literal names (`Key` for POSIX, `Index` for Windows) so this L3
    /// generic class can carry the canonical `Local` name without
    /// namespace collision.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// final class Frame { /* ... */ }
    ///
    /// let slot = Kernel.Thread.Local<Frame>()
    /// slot.value = Frame()           // retains
    /// // ... synchronous code on the same thread reads slot.value ...
    /// slot.value = nil               // releases
    /// ```
    ///
    /// Use case: thread-local context propagation for synchronous
    /// primitives that need to thread state across calls without
    /// explicit parameter passing — e.g., observation tracking
    /// contexts where SwiftUI body evaluation is synchronous and
    /// `TaskLocal` would not propagate.
    ///
    /// ## Thread safety
    ///
    /// `@unchecked Sendable` because the slot's per-thread isolation
    /// comes from the kernel TLS machinery — by construction, one
    /// thread cannot observe another thread's slot value. Sharing a
    /// `Local` instance across threads is the intended design (one
    /// platform key, many threads, each with its own slot).
    ///
    /// ## Cleanup caveat
    ///
    /// The wrapper's `deinit` does not enumerate per-thread slot values
    /// (POSIX TLS has no portable iteration API). Values set by threads
    /// other than the deinit'ing thread can leak if the `Local` instance
    /// is destroyed while other threads still hold values; in practice
    /// `Local` is held as a process-lifetime `static let` and the OS
    /// reclaims storage on exit.
    @safe
    public final class Local<Payload: AnyObject>: @unchecked Sendable {
        @usableFromInline
        let _slot: _PlatformSlot

        @inlinable
        public init() {
            _slot = _PlatformSlot()
        }

        /// The calling thread's slot value, or `nil` if the thread has
        /// not set one. The setter retains the new value and releases
        /// any previous retain — the slot owns one strong reference
        /// per thread for as long as the slot stays set.
        @inlinable
        public var value: Payload? {
            get {
                guard let opaque = unsafe _slot.value else { return nil }
                return unsafe Unmanaged<Payload>.fromOpaque(opaque).takeUnretainedValue()
            }
            set {
                if let oldOpaque = unsafe _slot.value {
                    unsafe Unmanaged<Payload>.fromOpaque(oldOpaque).release()
                }
                if let newValue {
                    let retained = unsafe Unmanaged.passRetained(newValue).toOpaque()
                    unsafe (_slot.value = retained)
                } else {
                    unsafe (_slot.value = nil)
                }
            }
        }
    }
}

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
@usableFromInline
internal typealias _PlatformSlot = ISO_9945.Kernel.Thread.Key
#elseif os(Windows)
@usableFromInline
internal typealias _PlatformSlot = Windows.Kernel.Thread.Index
#endif

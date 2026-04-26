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
    /// Per-thread storage slot — a policy-free wrapper around the
    /// platform's TLS key family, unified at L3.
    ///
    /// Resolves to:
    /// - POSIX: ``ISO_9945/Kernel/Thread/Local`` (`pthread_key_*`)
    /// - Windows: ``Windows/Kernel/Thread/Local`` (`TlsAlloc`/`TlsFree` family)
    ///
    /// Each `Local` instance owns one platform-allocated TLS key
    /// freed on `deinit`. The slot stores an
    /// `UnsafeMutableRawPointer?` per thread; consumers cast to/from
    /// their typed payload at the boundary.
    ///
    /// Per [PLAT-ARCH-005a], no platform C types appear in the public
    /// API: `pthread_key_t` / `DWORD` are internal storage; the slot
    /// type is `UnsafeMutableRawPointer?` (stdlib).
    ///
    /// ## Threading
    /// - **value (get)**: Returns the calling thread's slot value, or
    ///   `nil` if the thread has not set one (or has not allocated).
    /// - **value (set)**: Sets the calling thread's slot value.
    ///
    /// ## Usage
    /// ```swift
    /// let local = Kernel.Thread.Local()
    /// local.value = UnsafeMutableRawPointer(...)
    /// // ... synchronous code on the same thread reads `local.value` ...
    /// ```
    ///
    /// Use case: thread-local context propagation for synchronous
    /// primitives that need to thread state across calls without
    /// explicit parameter passing — e.g., observation tracking
    /// contexts where SwiftUI body evaluation is synchronous and
    /// `TaskLocal` would not propagate.
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public typealias Local = ISO_9945.Kernel.Thread.Local
    #elseif os(Windows)
    public typealias Local = Windows.Kernel.Thread.Local
    #endif
}

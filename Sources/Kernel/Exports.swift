// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

@_exported public import Kernel_Core
@_exported public import Kernel_Clock
@_exported public import Kernel_System
@_exported public import Kernel_Thread
@_exported public import Kernel_File
@_exported public import Kernel_Event
@_exported public import Kernel_Completion

// MARK: - Cycle 19 Descriptor typealias chain (typed handles at L2 spec packages)
//
// Per user direction 2026-04-30 + [PLAT-ARCH-005], typed descriptor lives at
// L2 spec packages per platform. This typealias chain at the L3-unifier
// resolves the cross-platform name `Kernel.Descriptor` to either
// `ISO_9945.Kernel.Descriptor` (POSIX, Int32 storage + close(2)) or
// `Windows.Kernel.Descriptor` (Windows, UInt storage + CloseHandle).
//
// Validity / Validity.Error / Validity.Error.Limit and Close / Close.Error
// and Duplicate / Duplicate.Error: all at L2 per-platform under the
// platform-namespaced types. The cross-platform `Kernel.Descriptor.X` names
// resolve via the typealias on the descriptor itself + ISO_9945.Kernel ==
// Kernel / Windows.Kernel == Kernel namespace identity.
//
// Note: ISO_9945.Kernel and Windows.Kernel are typealiases to
// Kernel_Primitives_Core.Kernel, so within their respective platform
// packages, `Kernel.Descriptor.Validity` resolves to the platform L2 type
// directly without further typealiasing.
//
// The L1 swift-kernel-primitives Kernel Descriptor Primitives target was
// deleted in Cycle 19. Cross-platform abstract vocabulary like `Interest`
// relocated to swift-kernel L3 (Kernel Core target).

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
extension Kernel {
    /// Cross-platform file descriptor (POSIX fd-shape on POSIX platforms).
    public typealias Descriptor = ISO_9945.Kernel.Descriptor
}
#elseif os(Windows)
extension Kernel {
    /// Cross-platform descriptor (Windows HANDLE-shape on Windows).
    public typealias Descriptor = Windows.Kernel.Descriptor
}
#endif

// Cross-paradigm Interest vocabulary lives at L1 as `Kernel.Event.Interest`
// (where its primary L1 consumer, Kernel.Event, references it). Expose it
// here under the descriptor namespace for L3+ consumers (Kernel.Completion,
// IO drivers, etc.) that think of readiness as a Descriptor-level concept.
extension Kernel.Descriptor {
    public typealias Interest = Kernel.Event.Interest
}

// MARK: - Cycle 21 Socket.Descriptor typealias chain (typed handles at L2)
//
// Per user direction 2026-04-30, typed handles relocate to L2 spec packages
// per platform (NOT L3-policy). This typealias chain at the L3-unifier
// resolves the cross-platform name `Kernel.Socket.Descriptor` to either
// `ISO_9945.Kernel.Socket.Descriptor` (POSIX, typealias to Kernel.Descriptor
// since fd=socket on POSIX) or `Windows.Kernel.Socket.Descriptor` (Windows,
// struct with `closesocket`-on-deinit). swift-kernel-primitives' Kernel
// Socket Primitives target was deleted in Cycle 21; vocab + errors absorbed
// at iso-9945 ISO 9945 Core.

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
@_exported public import ISO_9945_Kernel_Socket

extension Kernel.Socket {
    /// Cross-platform socket descriptor (POSIX fd-shape on POSIX platforms).
    public typealias Descriptor = ISO_9945.Kernel.Socket.Descriptor
}
#elseif os(Windows)
@_exported public import Windows_Kernel_Socket_Standard

extension Kernel.Socket {
    /// Cross-platform socket descriptor (Windows SOCKET-shape on Windows).
    public typealias Descriptor = Windows.Kernel.Socket.Descriptor
}
#endif

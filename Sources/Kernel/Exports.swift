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

// MARK: - G6.D namespace anchor (typealias-via-L3 per [PLAT-ARCH-005])
//
// Wave 3.5-Final-Atomic (2026-05-02): POSIX path flipped from
// `ISO_9945.Kernel` to `POSIX.Kernel`. Per Wave 3.5 envelope (Item 4 of
// post-Path-X cycles), POSIX-shared content is now wrapped at the
// `POSIX.Kernel.X` namespace with method-wrappers + value-type
// typealiases delegating to iso-9945 typed Phase 1.5 forms; the L3-unifier
// `Kernel` typealias targets POSIX.Kernel and typealias transitivity
// resolves the chain to iso-9945 (and L1 where applicable) at compile
// time, preserving L3-policy → L2 → L1 composition discipline per
// [PLAT-ARCH-008e]. The Windows path remains unchanged (Windows uses its
// own L3-policy chain via Windows.Kernel; no POSIX wrapping applies).
//
// Path X terminal: swift-kernel-primitives package deleted; Kernel root
// namespace lives at L2 spec packages canonically nested under their
// platform namespace (ISO_9945.Kernel for POSIX, Windows.Kernel for
// Windows). This public typealias provides the unified cross-platform
// `Kernel` name at L3.

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
public typealias Kernel = POSIX.Kernel
#elseif os(Windows)
public typealias Kernel = Windows.Kernel
#endif

// MARK: - Descriptor typealias chain (three-tier per [PLAT-ARCH-005] revised + [PLAT-ARCH-008e], Wave 4c-Socket Prerequisite II 2026-05-01)
//
// Per [PLAT-ARCH-005] revised + [PLAT-ARCH-008e] (Wave 4c-Socket Prerequisite II,
// 2026-05-01): the per-platform Descriptor is canonical at the L2 spec layer
// (POSIX → `ISO_9945.Kernel.Descriptor` at swift-iso-9945; Win32 →
// `Windows.\`32\`.Kernel.Descriptor` at swift-windows-32). The L3-policy
// packages (swift-posix / swift-windows) own `POSIX.Kernel.Descriptor` /
// `Windows.Kernel.Descriptor` as public typealiases of the L2 canonical
// types. This L3-unifier typealias targets the L3-policy name; typealias
// transitivity then resolves the chain to the L2 canonical at compile time,
// preserving the three-tier composition discipline (L3-unifier composes its
// peer L3-policy tier; never reaches across into L2).
//
// Validity / Validity.Error / Validity.Error.Limit / Close / Close.Error /
// Duplicate / Duplicate.Error: all canonically at L2 under the platform-namespaced
// types; `Kernel.Descriptor.X` resolves via typealias transitivity through the
// three-tier chain.
//
// The L1 swift-kernel-primitives Kernel Descriptor Primitives target was deleted
// in Cycle 19. Cross-platform abstract vocabulary like `Interest` relocated to
// swift-kernel L3 (Kernel Core target).

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
@_exported public import POSIX_Kernel_Descriptor
@_exported public import POSIX_Kernel_Directory

extension Kernel {
    /// Cross-platform file descriptor — composes through L3-policy per [PLAT-ARCH-008e].
    public typealias Descriptor = POSIX.Kernel.Descriptor
}
#elseif os(Windows)
@_exported public import Windows_Kernel_Descriptor

extension Kernel {
    /// Cross-platform descriptor — composes through L3-policy per [PLAT-ARCH-008e].
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

// MARK: - Socket.Descriptor typealias chain (three-tier per [PLAT-ARCH-005] + [PLAT-ARCH-008e], Wave 4c-Socket Prerequisite II 2026-05-01)
//
// Typed socket handles are canonical at L2 spec packages per platform:
// POSIX → `ISO_9945.Kernel.Socket.Descriptor` at swift-iso-9945 (typealias to
// Kernel.Descriptor since fd=socket on POSIX); Win32 →
// `Windows.\`32\`.Kernel.Socket.Descriptor` at swift-windows-32 (struct with
// `closesocket`-on-deinit). L3-policy packages (swift-posix / swift-windows)
// own `POSIX.Kernel.Socket.Descriptor` / `Windows.Kernel.Socket.Descriptor`
// as typealiases. This L3-unifier typealias targets the L3-policy name;
// the three-tier chain (L3-unifier → L3-policy → L2) composes one tier at
// a time per [PLAT-ARCH-008e]. swift-kernel-primitives' Kernel Socket
// Primitives target was deleted in Cycle 21; vocab + errors absorbed at
// iso-9945 ISO 9945 Core.

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
@_exported public import POSIX_Kernel_Socket

extension Kernel.Socket {
    /// Cross-platform socket descriptor — composes through L3-policy per [PLAT-ARCH-008e].
    public typealias Descriptor = POSIX.Kernel.Socket.Descriptor
}
#elseif os(Windows)
@_exported public import Windows_Kernel_Socket

extension Kernel.Socket {
    /// Cross-platform socket descriptor — composes through L3-policy per [PLAT-ARCH-008e].
    public typealias Descriptor = Windows.Kernel.Socket.Descriptor
}
#endif

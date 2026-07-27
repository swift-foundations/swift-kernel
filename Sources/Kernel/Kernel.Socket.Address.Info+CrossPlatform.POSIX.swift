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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)

    // MARK: - Cross-platform Address.Info surface on POSIX
    //
    // `Kernel.Socket.Address.Info` (getaddrinfo: `Info` / `Info.Hints` /
    // `Info.Options` / `Info.List` / `Info.Error`) resolves through the
    // L3-policy slot `POSIX_Kernel_Socket_Address` (swift-posix), which today
    // is a pure re-export of the L2 spec module
    // `ISO_9945_Kernel_Socket_Address` — the [PLAT-ARCH-008e] empty-tier
    // delegate shape. The slot reserves the namespace per [PLAT-ARCH-030];
    // when POSIX-side policy (for example EAI_AGAIN retry) lands there, this
    // surface picks it up without consumer changes.
    //
    // No typealias is declared here: `Kernel.Socket.Address` already resolves
    // to `ISO_9945.Kernel.Socket.Address` via the Wave 3.5 typealias chain
    // (`Kernel` → `POSIX.Kernel`; `POSIX.Kernel.Socket.Address` →
    // `ISO_9945.Kernel.Socket.Address`), so the nested `Info` family is
    // member-resolved through the same chain; a redundant `Info` typealias in
    // an extension would shadow the nested type and make every
    // `Kernel.Socket.Address.Info` reference ambiguous. The Windows leg
    // (`GetAddrInfoW` via swift-windows-32) lands later per the 2026-07-23
    // DNS system-resolver adjudication.
    //
    // The guard uses `#if os(...)` per [PATTERN-004a], mirroring the
    // manifest's `.when(platforms:)` condition on the slot product.

    @_exported public import POSIX_Kernel_Socket_Address

#endif

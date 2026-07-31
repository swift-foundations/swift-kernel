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

@_exported public import Kernel_Core
@_exported public import Kernel_System

#if os(Windows)
    // Re-export the per-domain `Windows Kernel Thread` L3-policy product so
    // the cross-platform `Kernel.Thread` name — and the per-member typealiases
    // hanging off it (`Error`, `Handle`, `ID`) — resolve on Windows.
    //
    // The former `Windows.Kernel.Thread.Affinity.apply(_:)` dispatch this
    // re-export existed for is gone: per swift-foundations/swift-windows#2 a
    // platform layer cannot accept the L3-unifier's affinity type, so kernel
    // performs the kind-switch itself in `Kernel.Thread.Affinity+Policy.swift`
    // and calls `Windows.\`32\`.Kernel.Thread.Affinity.setMask(cores:)`.
    @_exported public import Windows_Kernel_Thread
#endif

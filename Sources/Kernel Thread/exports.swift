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
    // Tier 5-Windows-FOS+Affinity-Combined Phase 5 (2026-05-02): re-export the
    // per-domain `Windows Kernel Thread` L3-policy product so the L3-unifier
    // `Kernel.Thread.Affinity.apply(_:)` dispatch can resolve
    // `Windows.Kernel.Thread.Affinity.apply(_:)` (declared at swift-windows
    // per Phase 3, commit `f40a2e9`).
    @_exported public import Windows_Kernel_Thread
#endif

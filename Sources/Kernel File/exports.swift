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

#if os(Windows)
    // Tier 5-Windows-FOS+Affinity-Combined Phase 5 (2026-05-02): re-export the
    // per-domain `Windows Kernel File` L3-policy product so cross-platform
    // consumers see the FOS triple (`Kernel.File.Offset/Size/Delta`) on Windows
    // via `Windows.Kernel.File.{Offset,Size,Delta}` (declared at swift-windows
    // per Phase 4, commit `8952d21`).
    @_exported public import Windows_Kernel_File
#endif

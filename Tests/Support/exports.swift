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

// Kernel Test Support — local content lives in sibling files in this
// directory (Kernel.Event.Test.Support.swift, Kernel.IO.Test.Helpers.swift,
// Kernel.Temporary.swift, Kernel.Thread.Test.Harness.swift, etc.). The
// pre-Path-X re-export chain to L1 swift-kernel-primitives' Test Support
// module is gone — that L1 module was deleted in Path X G6.D. The
// vestigial @_exported import was cleaned up in Wave 1.8 (2026-04-30).

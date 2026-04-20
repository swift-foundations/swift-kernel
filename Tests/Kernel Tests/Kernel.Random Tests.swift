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

import Kernel
import Testing

extension Kernel.Random {
    @Suite
    struct Test {
        @Suite struct Fill {}
    }
}

// MARK: - fill(_:) Smoke

extension Kernel.Random.Test.Fill {
    @Test
    func `fill(_:) on a 32-byte buffer produces non-zero bytes on every platform`() throws {
        var buffer = [UInt8](repeating: 0, count: 32)
        // Single cross-platform call site — no `#if os(...)`.
        // Darwin:  arc4random_buf (infallible, annotated throws for parity).
        // Linux:   getrandom(2) (blocking mode; EINTR handled in L2 wrapper).
        // Windows: BCryptGenRandom (NTSTATUS → Kernel.Random.Error).
        try unsafe buffer.withUnsafeMutableBytes { raw in
            try unsafe Kernel.Random.fill(raw)
        }
        let allZero = buffer.allSatisfy { $0 == 0 }
        #expect(!allZero)
    }

    @Test
    func `fill(_:) on an empty buffer is a no-op`() throws {
        var buffer: [UInt8] = []
        try unsafe buffer.withUnsafeMutableBytes { raw in
            try unsafe Kernel.Random.fill(raw)
        }
    }

    @Test
    func `successive fill(_:) calls produce different bytes`() throws {
        var first = [UInt8](repeating: 0, count: 32)
        var second = [UInt8](repeating: 0, count: 32)
        try unsafe first.withUnsafeMutableBytes { raw in
            try unsafe Kernel.Random.fill(raw)
        }
        try unsafe second.withUnsafeMutableBytes { raw in
            try unsafe Kernel.Random.fill(raw)
        }
        #expect(first != second)
    }
}

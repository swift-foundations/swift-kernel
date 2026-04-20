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
import Standard_Library_Extensions
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
    func `fill(_:) on a 32-byte buffer produces non-zero bytes on every platform`() throws(Kernel.Random.Error) {
        // 32 bytes of contiguous stack memory — a 4-tuple of UInt64.
        var buffer: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        // Single cross-platform call site — no `#if os(...)`.
        // Darwin:  arc4random_buf (infallible, annotated throws for parity).
        // Linux:   getrandom(2) (blocking mode; EINTR handled in L2 wrapper).
        // Windows: BCryptGenRandom (NTSTATUS → Kernel.Random.Error).
        try withUnsafeMutableBytes(of: &buffer) { raw throws(Kernel.Random.Error) in
            try unsafe Kernel.Random.fill(raw)
        }
        #expect(buffer != (0, 0, 0, 0))
    }

    @Test
    func `fill(_:) on an empty buffer is a no-op`() throws(Kernel.Random.Error) {
        let buffer = unsafe UnsafeMutableRawBufferPointer(start: nil, count: 0)
        try unsafe Kernel.Random.fill(buffer)
    }

    @Test
    func `successive fill(_:) calls produce different bytes`() throws(Kernel.Random.Error) {
        var first: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        var second: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        try withUnsafeMutableBytes(of: &first) { raw throws(Kernel.Random.Error) in
            try unsafe Kernel.Random.fill(raw)
        }
        try withUnsafeMutableBytes(of: &second) { raw throws(Kernel.Random.Error) in
            try unsafe Kernel.Random.fill(raw)
        }
        #expect(first != second)
    }
}

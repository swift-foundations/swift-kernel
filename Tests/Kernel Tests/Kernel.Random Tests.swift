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
    func `fill(_:) on a 32-byte buffer produces non-zero bytes on every platform`() throws(Kernel.Random.Error) {
        let count = 32
        let buffer = unsafe UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { unsafe buffer.deallocate() }
        unsafe buffer.initializeMemory(as: UInt8.self, repeating: 0)
        // Single cross-platform call site — no `#if os(...)`.
        // Darwin:  arc4random_buf (infallible, annotated throws for parity).
        // Linux:   getrandom(2) (blocking mode; EINTR handled in L2 wrapper).
        // Windows: BCryptGenRandom (NTSTATUS → Kernel.Random.Error).
        try unsafe Kernel.Random.fill(buffer)
        let allZero = unsafe buffer.allSatisfy { $0 == 0 }
        #expect(!allZero)
    }

    @Test
    func `fill(_:) on an empty buffer is a no-op`() throws(Kernel.Random.Error) {
        let buffer = unsafe UnsafeMutableRawBufferPointer(start: nil, count: 0)
        try unsafe Kernel.Random.fill(buffer)
    }

    @Test
    func `successive fill(_:) calls produce different bytes`() throws(Kernel.Random.Error) {
        let count = 32
        let first = unsafe UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { unsafe first.deallocate() }
        unsafe first.initializeMemory(as: UInt8.self, repeating: 0)
        let second = unsafe UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { unsafe second.deallocate() }
        unsafe second.initializeMemory(as: UInt8.self, repeating: 0)
        try unsafe Kernel.Random.fill(first)
        try unsafe Kernel.Random.fill(second)
        let firstBytes = unsafe Array(first)
        let secondBytes = unsafe Array(second)
        #expect(firstBytes != secondBytes)
    }
}

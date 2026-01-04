// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import StandardsTestSupport
import Testing

@testable import Kernel_Primitives

// Kernel.Memory.Address is a typealias to UnsafeMutableRawPointer
// #TestSuites cannot be used on typealiases

@Suite("Kernel.Memory.Address Tests")
struct MemoryAddressTests {

    @Test("Address is a typealias to UnsafeMutableRawPointer")
    func addressIsTypealias() {
        // The types should be identical
        let _: Kernel.Memory.Address.Type = UnsafeMutableRawPointer.self
    }

    @Test("Address can be created from allocation")
    func addressFromAllocation() {
        // Allocate some memory
        let address: Kernel.Memory.Address = .allocate(byteCount: 8, alignment: 8)
        defer { address.deallocate() }

        // Should be a valid pointer
        #expect(address != nil)
    }

    @Test("Address can be used to read and write")
    func addressReadWrite() {
        let address: Kernel.Memory.Address = .allocate(byteCount: 8, alignment: 8)
        defer { address.deallocate() }

        // Write a value
        address.storeBytes(of: UInt64(0xDEADBEEF), as: UInt64.self)

        // Read it back
        let value = address.load(as: UInt64.self)
        #expect(value == 0xDEADBEEF)
    }
}

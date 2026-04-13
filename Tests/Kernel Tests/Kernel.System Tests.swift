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

import Kernel_Test_Support
import Testing

@testable import Kernel

// MARK: - Kernel.System.Memory Tests

extension Kernel.System.Memory {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension Kernel.System.Memory.Test.Unit {
    @Test func `total memory is positive`() {
        let total = Kernel.System.Memory.total
        let bytes = UInt64(total)
        #expect(bytes > 0)
    }

    @Test func `total memory exceeds minimum threshold`() {
        let total = Kernel.System.Memory.total
        let bytes = UInt64(total)
        let sixtyFourMB: UInt64 = 64 * 1024 * 1024
        #expect(bytes >= sixtyFourMB)
    }

    @Test func `total memory is within reasonable upper bound`() {
        let total = Kernel.System.Memory.total
        let bytes = UInt64(total)
        let oneHundredTwentyEightTB: UInt64 = 128 * 1024 * 1024 * 1024 * 1024
        #expect(bytes <= oneHundredTwentyEightTB)
    }
}

// MARK: - Kernel.System.Processor Tests

extension Kernel.System.Processor {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension Kernel.System.Processor.Test.Unit {
    @Test func `logical processor count is positive`() {
        let count = Kernel.System.Processor.count
        let value = Int(count)
        #expect(value > 0)
    }

    @Test func `logical processor count is within reasonable upper bound`() {
        let count = Kernel.System.Processor.count
        let value = Int(count)
        #expect(value <= 4096)
    }
}

// MARK: - Kernel.System.Processor.Physical Tests

extension Kernel.System.Processor.Physical {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension Kernel.System.Processor.Physical.Test.Unit {
    @Test func `physical processor count is positive`() {
        let count = Kernel.System.Processor.Physical.count
        let value = Int(count)
        #expect(value > 0)
    }

    @Test func `physical count does not exceed logical count`() {
        let physical = Int(Kernel.System.Processor.Physical.count)
        let logical = Int(Kernel.System.Processor.count)
        #expect(physical <= logical)
    }

    @Test func `physical processor count is within reasonable upper bound`() {
        let count = Kernel.System.Processor.Physical.count
        let value = Int(count)
        #expect(value <= 4096)
    }
}

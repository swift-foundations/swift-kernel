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

// MARK: - System.Memory Tests

extension System.Memory {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

// F-001: `System.Memory.total` exists only on Apple platforms (swift-darwin)
// and Linux (swift-linux) — see Sources/Kernel System/Kernel.System.Memory.Total.swift.
// It is deliberately absent (compile-time, not a runtime crash) on
// Android/OpenBSD/Windows, so these tests are gated to where the API exists.
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)

    extension System.Memory.Test.Unit {
        @Test func `total memory is positive`() {
            let total = System.Memory.total
            let bytes = UInt64(total)
            #expect(bytes > 0)
        }

        @Test func `total memory exceeds minimum threshold`() {
            let total = System.Memory.total
            let bytes = UInt64(total)
            let sixtyFourMB: UInt64 = 64 * 1024 * 1024
            #expect(bytes >= sixtyFourMB)
        }

        @Test func `total memory is within reasonable upper bound`() {
            let total = System.Memory.total
            let bytes = UInt64(total)
            let oneHundredTwentyEightTB: UInt64 = 128 * 1024 * 1024 * 1024 * 1024
            #expect(bytes <= oneHundredTwentyEightTB)
        }
    }

#endif

// MARK: - System.Processor Tests

extension System.Processor {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension System.Processor.Test.Unit {
    @Test func `logical processor count is positive`() {
        let count = System.Processor.count
        let value = Int(count)
        #expect(value > 0)
    }

    @Test func `logical processor count is within reasonable upper bound`() {
        let count = System.Processor.count
        let value = Int(count)
        #expect(value <= 4096)
    }
}

// MARK: - System.Processor.Physical Tests

extension System.Processor.Physical {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension System.Processor.Physical.Test.Unit {
    @Test func `physical processor count is positive`() {
        let count = System.Processor.Physical.count
        let value = Int(count)
        #expect(value > 0)
    }

    @Test func `physical count does not exceed logical count`() {
        let physical = Int(System.Processor.Physical.count)
        let logical = Int(System.Processor.count)
        #expect(physical <= logical)
    }

    @Test func `physical processor count is within reasonable upper bound`() {
        let count = System.Processor.Physical.count
        let value = Int(count)
        #expect(value <= 4096)
    }
}

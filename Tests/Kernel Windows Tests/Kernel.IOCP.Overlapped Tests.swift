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

#if os(Windows)
import WinSDK
import StandardsTestSupport
import Testing

@testable import Kernel_Windows
import Kernel_Primitives

extension Kernel.IOCP.Overlapped {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.IOCP.Overlapped.Test.Unit {
    @Test("Overlapped type exists")
    func typeExists() {
        let _: Kernel.IOCP.Overlapped.Type = Kernel.IOCP.Overlapped.self
    }

    @Test("Overlapped default init creates zero-initialized structure")
    func defaultInit() {
        let overlapped = Kernel.IOCP.Overlapped()
        #expect(overlapped.offset == 0)
    }
}

// MARK: - Offset Tests

extension Kernel.IOCP.Overlapped.Test.Unit {
    @Test("offset get returns combined 64-bit value")
    func offsetGet() {
        var overlapped = Kernel.IOCP.Overlapped()
        overlapped.raw.Offset = 0xDEADBEEF
        overlapped.raw.OffsetHigh = 0x12345678

        let expected: Int64 = Int64(0x12345678) << 32 | Int64(0xDEADBEEF)
        #expect(overlapped.offset == expected)
    }

    @Test("offset set splits into low and high parts")
    func offsetSet() {
        var overlapped = Kernel.IOCP.Overlapped()
        let testOffset: Int64 = 0x123456789ABCDEF0

        overlapped.offset = testOffset

        #expect(overlapped.raw.Offset == 0x9ABCDEF0)
        #expect(overlapped.raw.OffsetHigh == 0x12345678)
    }

    @Test("offset roundtrip preserves value")
    func offsetRoundtrip() {
        var overlapped = Kernel.IOCP.Overlapped()

        let testValues: [Int64] = [
            0,
            1,
            Int64.max,
            0x7FFFFFFFFFFFFFFF,
            0x0000000100000000,
            0x00000000FFFFFFFF
        ]

        for value in testValues {
            overlapped.offset = value
            #expect(overlapped.offset == value)
        }
    }

    @Test("offset zero")
    func offsetZero() {
        var overlapped = Kernel.IOCP.Overlapped()
        overlapped.offset = 0
        #expect(overlapped.offset == 0)
        #expect(overlapped.raw.Offset == 0)
        #expect(overlapped.raw.OffsetHigh == 0)
    }
}

// MARK: - Conformance Tests

extension Kernel.IOCP.Overlapped.Test.Unit {
    @Test("Overlapped is Sendable")
    func isSendable() {
        let value: any Sendable = Kernel.IOCP.Overlapped()
        #expect(value is Kernel.IOCP.Overlapped)
    }
}

// MARK: - Edge Cases

extension Kernel.IOCP.Overlapped.Test.EdgeCase {
    @Test("offset handles 32-bit boundary values")
    func offsetBoundaryValues() {
        var overlapped = Kernel.IOCP.Overlapped()

        // Maximum 32-bit value (only low part used)
        overlapped.offset = 0xFFFFFFFF
        #expect(overlapped.raw.Offset == 0xFFFFFFFF)
        #expect(overlapped.raw.OffsetHigh == 0)
        #expect(overlapped.offset == 0xFFFFFFFF)

        // Minimum value for high part
        overlapped.offset = 0x100000000
        #expect(overlapped.raw.Offset == 0)
        #expect(overlapped.raw.OffsetHigh == 1)
        #expect(overlapped.offset == 0x100000000)
    }

    @Test("offset handles maximum positive Int64")
    func offsetMaxPositive() {
        var overlapped = Kernel.IOCP.Overlapped()
        overlapped.offset = Int64.max

        // Int64.max = 0x7FFFFFFFFFFFFFFF
        #expect(overlapped.raw.Offset == 0xFFFFFFFF)
        #expect(overlapped.raw.OffsetHigh == 0x7FFFFFFF)
        #expect(overlapped.offset == Int64.max)
    }

    @Test("offset set and get are consistent")
    func offsetConsistency() {
        var overlapped = Kernel.IOCP.Overlapped()

        // Set via property, verify raw fields match expected split
        overlapped.offset = 0xABCDEF0123456789

        // Note: This value is negative when interpreted as signed
        // but the bit pattern should be preserved
        let expectedLow = DWORD(truncatingIfNeeded: 0xABCDEF0123456789)
        let expectedHigh = DWORD(truncatingIfNeeded: 0xABCDEF0123456789 >> 32)

        #expect(overlapped.raw.Offset == expectedLow)
        #expect(overlapped.raw.OffsetHigh == expectedHigh)
    }

    @Test("multiple overlapped instances are independent")
    func multipleInstances() {
        var a = Kernel.IOCP.Overlapped()
        var b = Kernel.IOCP.Overlapped()

        a.offset = 100
        b.offset = 200

        #expect(a.offset == 100)
        #expect(b.offset == 200)

        a.offset = 300
        #expect(a.offset == 300)
        #expect(b.offset == 200)
    }
}

// MARK: - Memory Layout Tests

extension Kernel.IOCP.Overlapped.Test.Unit {
    @Test("Overlapped has correct memory layout for Windows interop")
    func memoryLayout() {
        // The wrapper should have the same layout as OVERLAPPED
        // to allow container-of pattern
        #expect(MemoryLayout<Kernel.IOCP.Overlapped>.size >= MemoryLayout<OVERLAPPED>.size)
    }
}

#endif

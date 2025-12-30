// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import StandardsTestSupport
import Testing

@testable import Kernel

extension Kernel.System {
    #TestSuites
}

// MARK: - Page Size Unit Tests

extension Kernel.System.Test.Unit {
    @Test("pageSize is positive")
    func pageSizePositive() {
        #expect(Kernel.System.pageSize > 0)
    }

    @Test("pageSize is power of 2")
    func pageSizePowerOfTwo() {
        let size = Kernel.System.pageSize
        // A power of 2 has exactly one bit set
        #expect(size & (size - 1) == 0)
    }

    @Test("pageSize is at least 4KB")
    func pageSizeMinimum() {
        // Most systems have at least 4KB pages
        #expect(Kernel.System.pageSize >= 4096)
    }

    #if os(macOS) && arch(arm64)
        @Test("pageSize is 16KB on Apple Silicon")
        func pageSizeAppleSilicon() {
            #expect(Kernel.System.pageSize == 16384)
        }
    #endif
}

// MARK: - Allocation Granularity Unit Tests

extension Kernel.System.Test.Unit {
    @Test("allocationGranularity is positive")
    func allocationGranularityPositive() {
        #expect(Kernel.System.allocationGranularity > 0)
    }

    @Test("allocationGranularity is power of 2")
    func allocationGranularityPowerOfTwo() {
        let size = Kernel.System.allocationGranularity
        #expect(size & (size - 1) == 0)
    }

    #if !os(Windows)
        @Test("allocationGranularity equals pageSize on POSIX")
        func allocationGranularityEqualsPageSize() {
            #expect(Kernel.System.allocationGranularity == Kernel.System.pageSize)
        }
    #endif
}

// MARK: - Consistency Tests

extension Kernel.System.Test.Unit {
    @Test("pageSize is consistent across calls")
    func pageSizeConsistent() {
        let size1 = Kernel.System.pageSize
        let size2 = Kernel.System.pageSize
        let size3 = Kernel.System.pageSize

        #expect(size1 == size2)
        #expect(size2 == size3)
    }

    @Test("allocationGranularity is consistent across calls")
    func allocationGranularityConsistent() {
        let size1 = Kernel.System.allocationGranularity
        let size2 = Kernel.System.allocationGranularity

        #expect(size1 == size2)
    }
}

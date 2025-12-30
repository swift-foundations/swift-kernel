//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import StandardsTestSupport
import Testing

@testable import Kernel

extension Kernel.Limits {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Limits.Test.Unit {
    @Test("pathMax is positive")
    func pathMaxPositive() {
        #expect(Kernel.Limits.pathMax > 0)
    }

    @Test("pathMax is reasonable")
    func pathMaxReasonable() {
        // PATH_MAX should be at least 256 on any platform
        #expect(Kernel.Limits.pathMax >= 256)
        // And not unreasonably large (sanity check)
        #expect(Kernel.Limits.pathMax <= 65536)
    }
}

// MARK: - Edge Cases

extension Kernel.Limits.Test.EdgeCase {
    #if os(macOS)
    @Test("macOS pathMax is 1024")
    func macOSPathMax() {
        #expect(Kernel.Limits.pathMax == 1024)
    }
    #endif

    #if os(Linux)
    @Test("Linux pathMax is typically 4096")
    func linuxPathMax() {
        #expect(Kernel.Limits.pathMax == 4096)
    }
    #endif
}

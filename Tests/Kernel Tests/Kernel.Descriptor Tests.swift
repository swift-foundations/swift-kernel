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

// Note: Kernel.Descriptor is a typealias, not a type
// We test the associated static members on Kernel instead

extension Kernel.Test.Unit {
    @Test("invalidDescriptor is negative on POSIX")
    func invalidDescriptorValue() {
        #if !os(Windows)
        #expect(Kernel.invalidDescriptor == -1)
        #endif
    }

    @Test("isValid returns false for invalid descriptor")
    func isValidFalseForInvalid() {
        #expect(!Kernel.isValid(Kernel.invalidDescriptor))
    }

    @Test("isValid returns true for valid descriptor")
    func isValidTrueForValid() {
        #if !os(Windows)
        // Standard input (0), stdout (1), stderr (2) are always valid
        #expect(Kernel.isValid(0))
        #expect(Kernel.isValid(1))
        #expect(Kernel.isValid(2))
        #endif
    }
}

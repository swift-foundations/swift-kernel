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

@testable import Kernel_Primitives

extension Kernel.Descriptor {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Descriptor.Test.Unit {
    @Test("invalid descriptor has correct raw value on POSIX")
    func invalidDescriptorValue() {
        #if !os(Windows)
            #expect(Kernel.Descriptor.invalid.rawValue == -1)
        #endif
    }

    @Test("isValid returns false for invalid descriptor")
    func isValidFalseForInvalid() {
        #expect(!Kernel.Descriptor.invalid.isValid)
    }

    @Test("isValid returns true for valid descriptor")
    func isValidTrueForValid() {
        #if !os(Windows)
            // Standard input (0), stdout (1), stderr (2) are always valid
            #expect(Kernel.Descriptor(rawValue: 0).isValid)
            #expect(Kernel.Descriptor(rawValue: 1).isValid)
            #expect(Kernel.Descriptor(rawValue: 2).isValid)
        #endif
    }
}

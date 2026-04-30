//
//  Kernel.Completion.Capabilities Tests.swift
//  swift-kernel-primitives
//

import Testing
import Kernel_Primitives_Test_Support

@testable import Kernel_Completion

extension Kernel.Completion.Capabilities {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Capabilities.Test.Unit {
    @Test
    func `default init has all capabilities false`() {
        let caps = Kernel.Completion.Capabilities()
        #expect(!caps.multishot)
        #expect(!caps.providedBuffers)
    }

    @Test
    func `init with explicit values`() {
        let caps = Kernel.Completion.Capabilities(
            multishot: true,
            providedBuffers: true
        )
        #expect(caps.multishot)
        #expect(caps.providedBuffers)
    }

    @Test
    func `partial capabilities`() {
        let caps = Kernel.Completion.Capabilities(
            multishot: true,
            providedBuffers: false
        )
        #expect(caps.multishot)
        #expect(!caps.providedBuffers)
    }

    @Test
    func `capabilities is sendable`() {
        let caps = Kernel.Completion.Capabilities()
        let _: any Sendable = caps
    }
}

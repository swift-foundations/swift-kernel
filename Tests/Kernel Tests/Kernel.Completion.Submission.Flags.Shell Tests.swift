//
//  Kernel.Completion.Submission.Flags Tests.swift
//  swift-kernel-primitives
//

import Testing
import Kernel_Primitives_Test_Support

@testable import Kernel_Completion

extension Kernel.Completion.Submission.Flags {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Submission.Flags.Test.Unit {
    @Test
    func `empty flags has zero rawValue`() {
        let flags: Kernel.Completion.Submission.Flags = []
        #expect(flags.rawValue == 0)
    }

    @Test
    func `roundtrip through rawValue`() {
        let flags = Kernel.Completion.Submission.Flags(rawValue: 0b1010)
        #expect(flags.rawValue == 0b1010)
    }

    @Test
    func `flags is sendable`() {
        let flags: Kernel.Completion.Submission.Flags = []
        let _: any Sendable = flags
    }
}

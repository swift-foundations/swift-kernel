//
//  Kernel.Completion.Token Tests.swift
//  swift-kernel-primitives
//

import Testing

@testable import Kernel_Completion

// Token is Tagged<Kernel.Completion, UInt64> — generic specialization.
// Parallel namespace per [SWIFT-TEST-003].

@Suite
struct `Completion Token Tests` {
    @Suite struct Unit {}
}

// MARK: - Unit Tests

extension `Completion Token Tests`.Unit {
    @Test
    func `zero token`() {
        let token = Kernel.Completion.Token.zero
        #expect(token == 0)
    }

    @Test
    func `init from identifier`() {
        let token = Kernel.Completion.Token(12345)
        #expect(token == 12345)
    }

    @Test
    func `tokens are equatable`() {
        let a = Kernel.Completion.Token(1)
        let b = Kernel.Completion.Token(1)
        let c = Kernel.Completion.Token(2)
        #expect(a == b)
        #expect(a != c)
    }
}

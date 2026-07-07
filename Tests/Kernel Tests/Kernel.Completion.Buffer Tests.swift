//
//  Kernel.Completion.Buffer Tests.swift
//  swift-kernel-primitives
//

import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Kernel_Completion

extension Kernel.Completion.Buffer {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Buffer.Test.Unit {
    @Test
    func `buffer namespace exists`() {
        _ = Kernel.Completion.Buffer.self
    }
}

// MARK: - Buffer.Group (Tagged — parallel namespace)

@Suite
struct `Completion Buffer Group Tests` {
    @Suite struct Unit {}
}

extension `Completion Buffer Group Tests`.Unit {
    @Test
    func `none group`() {
        let group = Kernel.Completion.Buffer.Group.none
        #expect(group == 0)
    }

    @Test
    func `init from identifier`() {
        let group = Kernel.Completion.Buffer.Group(7)
        #expect(group == 7)
    }

    @Test
    func `groups are equatable`() {
        let a = Kernel.Completion.Buffer.Group(1)
        let b = Kernel.Completion.Buffer.Group(1)
        let c = Kernel.Completion.Buffer.Group(2)
        #expect(a == b)
        #expect(a != c)
    }
}

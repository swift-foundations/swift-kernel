//
//  Kernel.Completion Tests.swift
//  swift-kernel-primitives
//

import Testing

@testable import Kernel_Completion

extension Kernel.Completion {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Test.Unit {
    @Test
    func `completion namespace exists`() {
        _ = Kernel.Completion.self
    }

    @Test
    func `token typealias exists`() {
        let _: Kernel.Completion.Token.Type = Kernel.Completion.Token.self
    }

    @Test
    func `submission typealias count exists`() {
        let _: Kernel.Completion.Submission.Count.Type = Kernel.Completion.Submission.Count.self
    }

    @Test
    func `event count typealias exists`() {
        let _: Kernel.Completion.Event.Count.Type = Kernel.Completion.Event.Count.self
    }
}

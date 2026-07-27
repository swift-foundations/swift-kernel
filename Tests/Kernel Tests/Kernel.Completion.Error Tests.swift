//
//  Kernel.Completion.Error Tests.swift
//  swift-kernel-primitives
//

import Testing

@testable import Kernel_Completion

extension Kernel.Completion.Error {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Error.Test.Unit {
    @Test
    func `submissionQueueFull is equatable`() {
        let a = Kernel.Completion.Error.submissionQueueFull
        let b = Kernel.Completion.Error.submissionQueueFull
        #expect(a == b)
    }

    @Test
    func `distinct cases are not equal`() {
        let a = Kernel.Completion.Error.submissionQueueFull
        let b = Kernel.Completion.Error.invalidDescriptor
        #expect(a != b)
    }

    @Test
    func `error conforms to Swift Error`() {
        let error: any Swift.Error = Kernel.Completion.Error.submissionQueueFull
        _ = error
    }

    @Test
    func `error is sendable`() {
        let error = Kernel.Completion.Error.invalidDescriptor
        let _: any Sendable = error
    }
}

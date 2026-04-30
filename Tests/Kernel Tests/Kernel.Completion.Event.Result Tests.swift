//
//  Kernel.Completion.Event.Result Tests.swift
//  swift-kernel-primitives
//

import Testing

@_spi(Syscall) @testable import Kernel_Completion

extension Kernel.Completion.Event.Result {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Event.Result.Test.Unit {
    @Test
    func `positive result is success`() {
        let result = Kernel.Completion.Event.Result(rawValue: 42)
        let isSuccess = result.isSuccess
        #expect(isSuccess)
    }

    @Test
    func `zero result is success`() {
        let result = Kernel.Completion.Event.Result(rawValue: 0)
        let isSuccess = result.isSuccess
        #expect(isSuccess)
    }

    @Test
    func `negative result is failure`() {
        let result = Kernel.Completion.Event.Result(rawValue: -1)
        let isSuccess = result.isSuccess
        #expect(!isSuccess)
    }

    @Test
    func `value returns rawValue on success`() {
        let result = Kernel.Completion.Event.Result(rawValue: 100)
        #expect(result.value == 100)
    }

    @Test
    func `value returns nil on failure`() {
        let result = Kernel.Completion.Event.Result(rawValue: -22)
        #expect(result.value == nil)
    }

    @Test
    func `result is equatable`() {
        let a = Kernel.Completion.Event.Result(rawValue: 10)
        let b = Kernel.Completion.Event.Result(rawValue: 10)
        let c = Kernel.Completion.Event.Result(rawValue: -1)
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - Edge Case Tests

extension Kernel.Completion.Event.Result.Test.`Edge Case` {
    @Test
    func `Int32 max is success`() {
        let result = Kernel.Completion.Event.Result(rawValue: .max)
        let isSuccess = result.isSuccess
        #expect(isSuccess)
        #expect(result.value == .max)
    }

    @Test
    func `Int32 min is failure`() {
        let result = Kernel.Completion.Event.Result(rawValue: .min)
        let isSuccess = result.isSuccess
        #expect(!isSuccess)
        #expect(result.value == nil)
    }

    @Test
    func `minus one is failure`() {
        let result = Kernel.Completion.Event.Result(rawValue: -1)
        let isSuccess = result.isSuccess
        #expect(!isSuccess)
    }
}

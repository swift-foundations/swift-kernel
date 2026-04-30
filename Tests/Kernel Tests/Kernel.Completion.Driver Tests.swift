//
//  Kernel.Completion.Driver Tests.swift
//  swift-kernel-primitives
//

#if KERNEL_AVAILABLE

import Testing
import Kernel_Primitives_Test_Support

@_spi(Syscall) @testable import Kernel_Completion

extension Kernel.Completion.Driver {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Driver.Test.Unit {
    @Test
    func `init wires submit closure`() {
        var called = false
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in called = true },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let sentinel = Kernel.Descriptor.invalid
        try! driver._submit(
            Kernel.Completion.Submission(opcode: .noOperation, token: .zero),
            sentinel
        )
        #expect(called)
    }

    @Test
    func `init wires flush closure`() {
        var called = false
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { called = true; return .zero },
            drain: { _ in .zero },
            close: { }
        )
        _ = try! driver._flush()
        #expect(called)
    }

    @Test
    func `init wires drain closure`() {
        var called = false
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in called = true; return .zero },
            close: { }
        )
        _ = driver._drain { _ in }
        #expect(called)
    }

    @Test
    func `init wires close closure`() {
        var called = false
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { called = true }
        )
        driver._close()
        #expect(called)
    }

    @Test
    func `overflowCount defaults to zero`() {
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        #expect(driver._overflowCount() == .zero)
    }

    @Test
    func `overflowCount wires custom closure`() {
        let count: Kernel.Completion.Event.Count = 42
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { },
            overflowCount: { count }
        )
        #expect(driver._overflowCount() == 42)
    }

    @Test
    func `drain delivers events to visitor`() {
        let event = Kernel.Completion.Event(
            token: .init(1),
            result: .init(rawValue: 64),
            flags: []
        )
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { visitor in visitor(event); return 1 },
            close: { }
        )
        var received: [Kernel.Completion.Token] = []
        _ = driver._drain { received.append($0.token) }
        #expect(received.count == 1)
        #expect(received[0] == 1)
    }
}

#endif

//
//  Kernel.Completion.Event Tests.swift
//  swift-kernel-primitives
//

import Testing

@_spi(Syscall) @testable import Kernel_Completion

extension Kernel.Completion.Event {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Event.Test.Unit {
    @Test
    func `init with defaults`() {
        let event = Kernel.Completion.Event(
            token: .zero,
            result: .init(rawValue: 0)
        )
        #expect(event.token == 0)
        let isSuccess = event.result.isSuccess
        #expect(isSuccess)
        #expect(event.flags == [])
    }

    @Test
    func `init with flags`() {
        let event = Kernel.Completion.Event(
            token: .init(42),
            result: .init(rawValue: 100),
            flags: .more
        )
        #expect(event.token == 42)
        #expect(event.result.value == 100)
        let hasMore = event.flags.contains(.more)
        #expect(hasMore)
    }

    @Test
    func `event is sendable`() {
        let event = Kernel.Completion.Event(
            token: .zero,
            result: .init(rawValue: 0)
        )
        let _: any Sendable = event
    }
}

// MARK: - Event.Flags

extension Kernel.Completion.Event.Flags {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Kernel.Completion.Event.Flags.Test.Unit {
    @Test
    func `more flag has nonzero rawValue`() {
        let more = Kernel.Completion.Event.Flags.more
        #expect(more.rawValue != 0)
    }

    @Test
    func `empty flags`() {
        let empty: Kernel.Completion.Event.Flags = []
        #expect(empty.rawValue == 0)
        let hasMore = empty.contains(.more)
        #expect(!hasMore)
    }
}

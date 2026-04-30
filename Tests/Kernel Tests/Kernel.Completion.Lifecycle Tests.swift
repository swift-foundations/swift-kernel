//
//  Kernel.Completion.Lifecycle Tests.swift
//  swift-kernel-primitives
//
//  Adversarial and integration tests verifying L1 promotion correctness.
//

#if KERNEL_AVAILABLE

import Testing
import Kernel_Primitives_Test_Support

@_spi(Syscall) @testable import Kernel_Completion

@Suite
struct `Completion Lifecycle Tests` {
    @Suite struct `Full Lifecycle` {}
    @Suite struct `Error Propagation` {}
    @Suite struct `Untargeted Submit` {}
    @Suite struct `Drain Delivery` {}
    @Suite struct `Submission Independence` {}
    @Suite struct `Flags Composability` {}
    @Suite struct `Result Boundary` {}
    @Suite struct `Token Identity` {}
    @Suite struct `Notification Ownership` {}
}

// MARK: - Full Lifecycle

extension `Completion Lifecycle Tests`.`Full Lifecycle` {
    @Test
    func `create submit flush drain close sequence`() {
        var submitLog: [(Kernel.Completion.Submission.Opcode, Kernel.Completion.Token)] = []
        var flushCount = 0
        var closeCount = 0
        let overflowSentinel: Kernel.Completion.Event.Count = 7

        let events: [Kernel.Completion.Event] = [
            .init(token: .init(1), result: .init(rawValue: 64), flags: []),
            .init(token: .init(2), result: .init(rawValue: 128), flags: .more),
            .init(token: .init(3), result: .init(rawValue: -1), flags: []),
        ]

        let driver = Kernel.Completion.Driver(
            submit: { submission, _ in
                submitLog.append((submission.opcode, submission.token))
            },
            flush: {
                flushCount += 1
                return 2
            },
            drain: { visitor in
                for event in events { visitor(event) }
                return 3
            },
            close: { closeCount += 1 },
            overflowCount: { overflowSentinel }
        )

        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )

        // Submit two operations
        let address: Memory.Address = 0x1000
        let sub1 = Kernel.Completion.Submission(
            opcode: .read(address: address, length: 64, offset: nil),
            token: 1
        )
        let sub2 = Kernel.Completion.Submission(
            opcode: .write(address: address, length: 128, offset: nil),
            token: 2
        )
        let sentinel = Kernel.Descriptor.invalid
        try! completion.submit(sub1, target: sentinel)
        try! completion.submit(sub2, target: sentinel)

        #expect(submitLog.count == 2)
        if case .read = submitLog[0].0 {} else {
            Issue.record("submitLog[0] expected .read")
        }
        #expect(submitLog[0].1 == 1)
        if case .write = submitLog[1].0 {} else {
            Issue.record("submitLog[1] expected .write")
        }
        #expect(submitLog[1].1 == 2)

        // Flush
        let flushed = try! completion.flush()
        #expect(flushCount == 1)
        #expect(flushed == 2)

        // Drain
        var received: [(Kernel.Completion.Token, Int32)] = []
        let drained = completion.drain { event in
            let rawValue = event.result.rawValue
            received.append((event.token, rawValue))
        }
        #expect(drained == 3)
        #expect(received.count == 3)
        #expect(received[0].0 == 1)
        #expect(received[0].1 == 64)
        #expect(received[1].0 == 2)
        #expect(received[1].1 == 128)
        #expect(received[2].0 == 3)
        #expect(received[2].1 == -1)

        // Overflow count
        let overflow = completion.overflowCount
        #expect(overflow == 7)

        // Close
        completion.close()
        #expect(closeCount == 1)
    }

    @Test
    func `close is called exactly once`() {
        var closeCount = 0
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { closeCount += 1 }
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )
        completion.close()
        #expect(closeCount == 1)
    }
}

// MARK: - Error Propagation

extension `Completion Lifecycle Tests`.`Error Propagation` {
    @Test
    func `submit propagates submissionQueueFull`() throws {
        let error: Kernel.Completion.Error = .submissionQueueFull
        let driver = Kernel.Completion.Driver(
            submit: { (_, _) throws(Kernel.Completion.Error) in throw error },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )
        let sub = Kernel.Completion.Submission(opcode: .noOperation, token: .zero)
        #expect(throws: Kernel.Completion.Error.submissionQueueFull) {
            try completion.submit(sub)
        }
        completion.close()
    }

    @Test
    func `flush propagates platform error with exact code`() throws {
        let code = Error_Primitives.Error.Code.posix(28) // ENOSPC
        let error: Kernel.Completion.Error = .platform(code)
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { () throws(Kernel.Completion.Error) in throw error },
            drain: { _ in .zero },
            close: { }
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )
        #expect(throws: Kernel.Completion.Error.platform(code)) {
            try completion.flush()
        }
        completion.close()
    }

    @Test
    func `submit propagates invalidDescriptor`() throws {
        let error: Kernel.Completion.Error = .invalidDescriptor
        let driver = Kernel.Completion.Driver(
            submit: { (_, _) throws(Kernel.Completion.Error) in throw error },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )
        let sub = Kernel.Completion.Submission(opcode: .noOperation, token: .zero)
        #expect(throws: Kernel.Completion.Error.invalidDescriptor) {
            try completion.submit(sub)
        }
        completion.close()
    }
}

// MARK: - Untargeted Submit

extension `Completion Lifecycle Tests`.`Untargeted Submit` {
    @Test
    func `untargeted submit passes invalid descriptor sentinel`() {
        var receivedRawDescriptor: Int32? = nil
        let driver = Kernel.Completion.Driver(
            submit: { _, descriptor in
                receivedRawDescriptor = descriptor._rawValue
            },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )
        let sub = Kernel.Completion.Submission(opcode: .noOperation, token: .zero)
        try! completion.submit(sub)

        let invalidRaw = Kernel.Descriptor.invalid._rawValue
        #expect(receivedRawDescriptor == invalidRaw)
        completion.close()
    }
}

// MARK: - Drain Delivery

extension `Completion Lifecycle Tests`.`Drain Delivery` {
    @Test
    func `drain delivers events with more flag`() {
        let event = Kernel.Completion.Event(
            token: .init(10),
            result: .init(rawValue: 256),
            flags: .more
        )
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { visitor in visitor(event); return 1 },
            close: { }
        )
        var receivedFlags: Kernel.Completion.Event.Flags?
        _ = driver._drain { receivedFlags = $0.flags }
        let hasMore = receivedFlags?.contains(.more)
        #expect(hasMore == true)
    }

    @Test
    func `drain delivers negative results faithfully`() {
        let event = Kernel.Completion.Event(
            token: .init(1),
            result: .init(rawValue: -22), // EINVAL
            flags: []
        )
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { visitor in visitor(event); return 1 },
            close: { }
        )
        var receivedRaw: Int32?
        _ = driver._drain { receivedRaw = $0.result.rawValue }
        #expect(receivedRaw == -22)
    }

    @Test
    func `drain returns correct count`() {
        let events: [Kernel.Completion.Event] = [
            .init(token: .init(1), result: .init(rawValue: 10)),
            .init(token: .init(2), result: .init(rawValue: 20)),
            .init(token: .init(3), result: .init(rawValue: 30)),
            .init(token: .init(4), result: .init(rawValue: 40)),
            .init(token: .init(5), result: .init(rawValue: 50)),
        ]
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { visitor in
                for event in events { visitor(event) }
                return 5
            },
            close: { }
        )
        let count = driver._drain { _ in }
        #expect(count == 5)
    }

    @Test
    func `drain with zero events returns zero and never calls visitor`() {
        var visitorCalled = false
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let count = driver._drain { _ in visitorCalled = true }
        #expect(count == .zero)
        #expect(!visitorCalled)
    }

    @Test
    func `drain preserves token ordering across multiple events`() {
        let events: [Kernel.Completion.Event] = [
            .init(token: .init(100), result: .init(rawValue: 0)),
            .init(token: .init(200), result: .init(rawValue: 0)),
            .init(token: .init(300), result: .init(rawValue: 0)),
        ]
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { visitor in
                for event in events { visitor(event) }
                return 3
            },
            close: { }
        )
        var receivedTokens: [Kernel.Completion.Token] = []
        _ = driver._drain { receivedTokens.append($0.token) }
        #expect(receivedTokens.count == 3)
        #expect(receivedTokens[0] == 100)
        #expect(receivedTokens[1] == 200)
        #expect(receivedTokens[2] == 300)
    }
}

// MARK: - Submission Independence

extension `Completion Lifecycle Tests`.`Submission Independence` {
    @Test
    func `two submissions have independent opcodes`() {
        let address: Memory.Address = 0x1000
        let sub1 = Kernel.Completion.Submission(
            opcode: .read(address: address, length: 4096, offset: nil),
            token: 1
        )
        let sub2 = Kernel.Completion.Submission(
            opcode: .write(address: address, length: 8192, offset: 0),
            token: 2
        )

        #expect(sub1.token == 1)
        #expect(sub2.token == 2)
        guard case .read(_, let l1, let o1) = sub1.opcode else {
            Issue.record("expected .read"); return
        }
        guard case .write(_, let l2, let o2) = sub2.opcode else {
            Issue.record("expected .write"); return
        }
        #expect(l1 == 4096)
        #expect(o1 == nil)
        #expect(l2 == 8192)
        #expect(o2 == 0)
    }

    @Test
    func `modifying one field does not affect others`() {
        let token: Kernel.Completion.Token = 42
        var sub = Kernel.Completion.Submission(
            opcode: .noOperation,
            token: token,
            flags: .init(rawValue: 0xF)
        )

        sub.opcode = .close
        #expect(sub.opcode == .close)
        #expect(sub.token == 42)
        #expect(sub.flags.rawValue == 0xF)
        #expect(sub.bufferGroup == .none)
    }

    @Test
    func `default values are correct`() {
        let sub = Kernel.Completion.Submission(opcode: .noOperation, token: .zero)
        #expect(sub.flags == [])
        #expect(sub.bufferGroup == .none)
    }
}

// MARK: - Flags Composability

extension `Completion Lifecycle Tests`.`Flags Composability` {
    @Test
    func `empty flags has rawValue zero`() {
        let flags: Kernel.Completion.Submission.Flags = []
        #expect(flags.rawValue == 0)
    }

    @Test
    func `arbitrary rawValues round trip`() {
        let flags = Kernel.Completion.Submission.Flags(rawValue: 0xDEAD)
        #expect(flags.rawValue == 0xDEAD)
    }

    @Test
    func `union combines bits`() {
        let a = Kernel.Completion.Submission.Flags(rawValue: 0b0011)
        let b = Kernel.Completion.Submission.Flags(rawValue: 0b1100)
        let combined = a.union(b)
        #expect(combined.rawValue == 0b1111)
    }

    @Test
    func `intersection retains common bits`() {
        let a = Kernel.Completion.Submission.Flags(rawValue: 0b1010)
        let b = Kernel.Completion.Submission.Flags(rawValue: 0b1100)
        let common = a.intersection(b)
        #expect(common.rawValue == 0b1000)
    }

    @Test
    func `subtraction removes bits`() {
        let a = Kernel.Completion.Submission.Flags(rawValue: 0b1111)
        let b = Kernel.Completion.Submission.Flags(rawValue: 0b0011)
        let result = a.subtracting(b)
        #expect(result.rawValue == 0b1100)
    }

    @Test
    func `contains works on constructed flags`() {
        let flagA = Kernel.Completion.Submission.Flags(rawValue: 1 << 0)
        let flagB = Kernel.Completion.Submission.Flags(rawValue: 1 << 3)
        let combined: Kernel.Completion.Submission.Flags = [flagA, flagB]

        let hasA = combined.contains(flagA)
        let hasB = combined.contains(flagB)
        let hasMissing = combined.contains(.init(rawValue: 1 << 7))
        #expect(hasA)
        #expect(hasB)
        #expect(!hasMissing)
    }

    @Test
    func `array literal combines distinct bits`() {
        let flagA = Kernel.Completion.Submission.Flags(rawValue: 1 << 1)
        let flagB = Kernel.Completion.Submission.Flags(rawValue: 1 << 5)
        let combined: Kernel.Completion.Submission.Flags = [flagA, flagB]
        #expect(combined.rawValue == (1 << 1) | (1 << 5))
    }
}

// MARK: - Result Boundary

extension `Completion Lifecycle Tests`.`Result Boundary` {
    @Test
    func `rawValue zero is success with value zero`() {
        let result = Kernel.Completion.Event.Result(rawValue: 0)
        let isSuccess = result.isSuccess
        #expect(isSuccess)
        #expect(result.value == 0)
    }

    @Test
    func `rawValue minus one is failure with nil value`() {
        let result = Kernel.Completion.Event.Result(rawValue: -1)
        let isSuccess = result.isSuccess
        #expect(!isSuccess)
        #expect(result.value == nil)
    }

    @Test
    func `rawValue Int32 max is success`() {
        let result = Kernel.Completion.Event.Result(rawValue: .max)
        let isSuccess = result.isSuccess
        #expect(isSuccess)
        #expect(result.value == Int32.max)
    }

    @Test
    func `rawValue Int32 min is failure`() {
        let result = Kernel.Completion.Event.Result(rawValue: .min)
        let isSuccess = result.isSuccess
        #expect(!isSuccess)
        #expect(result.value == nil)
    }

    @Test
    func `rawValue one is success with bytes transferred`() {
        let result = Kernel.Completion.Event.Result(rawValue: 1)
        let isSuccess = result.isSuccess
        #expect(isSuccess)
        #expect(result.value == 1)
    }

    @Test
    func `consecutive negative values are all failures`() {
        for raw in Int32(-100) ... Int32(-1) {
            let result = Kernel.Completion.Event.Result(rawValue: raw)
            let isSuccess = result.isSuccess
            #expect(!isSuccess, "rawValue \(raw) should be failure")
            #expect(result.value == nil, "rawValue \(raw) should have nil value")
        }
    }
}

// MARK: - Token Identity

extension `Completion Lifecycle Tests`.`Token Identity` {
    @Test
    func `same value tokens are equal`() {
        let a = Kernel.Completion.Token(42)
        let b = Kernel.Completion.Token(42)
        #expect(a == b)
    }

    @Test
    func `different value tokens are not equal`() {
        let a = Kernel.Completion.Token(1)
        let b = Kernel.Completion.Token(2)
        #expect(a != b)
    }

    @Test
    func `Token zero equals Token init zero`() {
        let zero = Kernel.Completion.Token.zero
        let explicit = Kernel.Completion.Token(0)
        #expect(zero == explicit)
    }

    @Test
    func `token max value round trips`() {
        let token = Kernel.Completion.Token(UInt64.max)
        #expect(token.rawValue == UInt64.max)
    }
}

// MARK: - Notification Ownership

extension `Completion Lifecycle Tests`.`Notification Ownership` {
    @Test
    func `notification descriptor is accessible`() {
        let descriptor = Kernel.Descriptor.invalid
        let notification = Kernel.Completion.Notification(descriptor: descriptor)
        let rawValue = notification.descriptor._rawValue
        let invalidRaw = Kernel.Descriptor.invalid._rawValue
        #expect(rawValue == invalidRaw)
    }

    @Test
    func `completion with notification stores it`() {
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let notification = Kernel.Completion.Notification(
            descriptor: Kernel.Descriptor.invalid
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: notification,
            capabilities: Kernel.Completion.Capabilities()
        )
        // Notification is ~Copyable, so access through Completion
        // verifies the Optional<~Copyable> storage works
        let hasNotification = completion.notification != nil
        #expect(hasNotification)
        completion.close()
    }

    @Test
    func `completion without notification stores nil`() {
        let driver = Kernel.Completion.Driver(
            submit: { _, _ in },
            flush: { .zero },
            drain: { _ in .zero },
            close: { }
        )
        let completion = Kernel.Completion(
            driver: driver,
            wakeup: Kernel.Wakeup.Channel(signal: {}),
            notification: nil,
            capabilities: Kernel.Completion.Capabilities()
        )
        let hasNotification = completion.notification != nil
        #expect(!hasNotification)
        completion.close()
    }

    // Notification is ~Copyable — assigning to two variables is a
    // compile-time error. This is enforced by the type system and
    // does not require a runtime test.
}

#endif

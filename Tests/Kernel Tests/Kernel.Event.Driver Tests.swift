//
//  Kernel.Event.Driver Tests.swift
//  swift-kernel-primitives
//

import Kernel_Test_Support
import Testing

@testable import Kernel

extension Kernel.Event.Driver {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Interest Merging

extension Kernel.Event.Driver.Test.Unit {

    @Test
    func `sequential arms for different interests merge into combined mask`() throws {
        var armInterests: [Kernel.Event.Interest] = []

        let driver = Kernel.Event.Driver(
            add: { _, _, _ in },
            modify: { _, _, _, _ in },
            remove: { _, _, _ in },
            arm: { _, _, interest in armInterests.append(interest) },
            poll: { _, _ in 0 },
            close: {}
        )

        let id = try driver._register(Kernel.Descriptor.invalid, [.read, .write])

        try driver._arm(id, .read)
        #expect(armInterests.count == 1)
        #expect(armInterests[0] == .read)

        try driver._arm(id, .write)
        #expect(armInterests.count == 2)
        #expect(armInterests[1] == [.read, .write])

        driver._close()
    }

    @Test
    func `arming same interest twice is idempotent`() throws {
        var armInterests: [Kernel.Event.Interest] = []

        let driver = Kernel.Event.Driver(
            add: { _, _, _ in },
            modify: { _, _, _, _ in },
            remove: { _, _, _ in },
            arm: { _, _, interest in armInterests.append(interest) },
            poll: { _, _ in 0 },
            close: {}
        )

        let id = try driver._register(Kernel.Descriptor.invalid, .read)

        try driver._arm(id, .read)
        try driver._arm(id, .read)

        #expect(armInterests.count == 2)
        #expect(armInterests[0] == .read)
        #expect(armInterests[1] == .read)

        driver._close()
    }
}

// MARK: - Poll Re-Arm

extension Kernel.Event.Driver.Test.Unit {

    @Test
    func `poll re-arms for residual interest after partial delivery`() throws {
        var armInterests: [Kernel.Event.Interest] = []
        var registeredID = Kernel.Event.ID.zero
        var shouldDeliver = false

        let driver = Kernel.Event.Driver(
            add: { _, id, _ in registeredID = id },
            modify: { _, _, _, _ in },
            remove: { _, _, _ in },
            arm: { _, _, interest in armInterests.append(interest) },
            poll: { _, output in
                guard shouldDeliver else { return 0 }
                shouldDeliver = false
                output[0] = Kernel.Event(id: registeredID, interest: .read)
                return 1
            },
            close: {}
        )

        let id = try driver._register(Kernel.Descriptor.invalid, [.read, .write])

        try driver._arm(id, .read)
        try driver._arm(id, .write)
        armInterests.removeAll()

        shouldDeliver = true
        var buffer = [Kernel.Event](repeating: .empty, count: 8)
        let count = try driver._poll(nil, &buffer)

        #expect(count == 1)
        #expect(buffer[0].interest == .read)
        #expect(armInterests.count == 1)
        #expect(armInterests[0] == .write)

        driver._close()
    }

    @Test
    func `poll does not re-arm when all interests are delivered`() throws {
        var armCallCount = 0
        var registeredID = Kernel.Event.ID.zero
        var shouldDeliver = false

        let driver = Kernel.Event.Driver(
            add: { _, id, _ in registeredID = id },
            modify: { _, _, _, _ in },
            remove: { _, _, _ in },
            arm: { _, _, _ in armCallCount += 1 },
            poll: { _, output in
                guard shouldDeliver else { return 0 }
                shouldDeliver = false
                output[0] = Kernel.Event(id: registeredID, interest: [.read, .write])
                return 1
            },
            close: {}
        )

        let id = try driver._register(Kernel.Descriptor.invalid, [.read, .write])

        try driver._arm(id, .read)
        try driver._arm(id, .write)
        armCallCount = 0

        shouldDeliver = true
        var buffer = [Kernel.Event](repeating: .empty, count: 8)
        _ = try driver._poll(nil, &buffer)

        #expect(armCallCount == 0)

        driver._close()
    }

    @Test
    func `single interest has no residual after delivery`() throws {
        var armInterests: [Kernel.Event.Interest] = []
        var registeredID = Kernel.Event.ID.zero
        var shouldDeliver = false

        let driver = Kernel.Event.Driver(
            add: { _, id, _ in registeredID = id },
            modify: { _, _, _, _ in },
            remove: { _, _, _ in },
            arm: { _, _, interest in armInterests.append(interest) },
            poll: { _, output in
                guard shouldDeliver else { return 0 }
                shouldDeliver = false
                output[0] = Kernel.Event(id: registeredID, interest: .read)
                return 1
            },
            close: {}
        )

        let id = try driver._register(Kernel.Descriptor.invalid, .read)

        try driver._arm(id, .read)
        armInterests.removeAll()

        shouldDeliver = true
        var buffer = [Kernel.Event](repeating: .empty, count: 8)
        _ = try driver._poll(nil, &buffer)

        #expect(armInterests.isEmpty)

        driver._close()
    }

    @Test
    func `delivery resets armed interest — subsequent arm starts fresh`() throws {
        var armInterests: [Kernel.Event.Interest] = []
        var registeredID = Kernel.Event.ID.zero
        var shouldDeliver = false

        let driver = Kernel.Event.Driver(
            add: { _, id, _ in registeredID = id },
            modify: { _, _, _, _ in },
            remove: { _, _, _ in },
            arm: { _, _, interest in armInterests.append(interest) },
            poll: { _, output in
                guard shouldDeliver else { return 0 }
                shouldDeliver = false
                output[0] = Kernel.Event(id: registeredID, interest: [.read, .write])
                return 1
            },
            close: {}
        )

        let id = try driver._register(Kernel.Descriptor.invalid, [.read, .write])

        try driver._arm(id, .read)
        try driver._arm(id, .write)

        shouldDeliver = true
        var buffer = [Kernel.Event](repeating: .empty, count: 8)
        _ = try driver._poll(nil, &buffer)

        armInterests.removeAll()

        try driver._arm(id, .read)

        #expect(armInterests.count == 1)
        #expect(armInterests[0] == .read)

        driver._close()
    }
}

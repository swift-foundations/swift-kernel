// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Kernel
import Kernel_Test_Support
import Synchronization
import Testing

extension Kernel.Thread.Spawn {
    enum Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Kernel.Thread.Spawn.Test.Unit {
    @Test
    func `spawn creates thread that executes body`() throws {
        let executed = Atomic<Bool>(false)
        let handle = try Kernel.Thread.spawn {
            executed.store(true, ordering: .releasing)
        }
        handle.join()
        #expect(executed.load(ordering: .acquiring) == true)
    }

    @Test
    func `spawn with value transfers ownership`() throws {
        let receivedValue = Atomic<Int>(0)
        let handle = try Kernel.Thread.spawn(42) { value in
            receivedValue.store(value, ordering: .releasing)
        }
        handle.join()
        #expect(receivedValue.load(ordering: .acquiring) == 42)
    }

    @Test
    func `Handle.join waits for thread completion`() throws {
        let completed = Atomic<Bool>(false)
        let handle = try Kernel.Thread.spawn {
            // Small delay to ensure we're actually waiting
            for _ in 0..<1000 {
                _ = 1 + 1  // Busy work
            }
            completed.store(true, ordering: .releasing)
        }

        handle.join()
        #expect(completed.load(ordering: .acquiring) == true)
    }

    @Test
    func `Handle.isCurrent returns false from main thread`() throws {
        let handle = try Kernel.Thread.spawn {
            // Do nothing
        }

        // From main thread, isCurrent should be false
        #expect(handle.isCurrent == false)

        handle.join()
    }
}

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
import Test_Support_Primitives
import Synchronization
import Testing

extension Kernel.Thread.Spawn {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Thread.Spawn.Test.Unit {
    @Test("spawn creates thread that executes body")
    func spawnExecutesBody() throws {
        let executed = Atomic<Bool>(false)
        let handle = try Kernel.Thread.spawn {
            executed.store(true, ordering: .releasing)
        }
        handle.join()
        #expect(executed.load(ordering: .acquiring) == true)
    }

    @Test("spawn with value transfers ownership")
    func spawnWithValueTransfersOwnership() throws {
        let receivedValue = Atomic<Int>(0)
        let handle = try Kernel.Thread.spawn(42) { value in
            receivedValue.store(value, ordering: .releasing)
        }
        handle.join()
        #expect(receivedValue.load(ordering: .acquiring) == 42)
    }

    @Test("Handle.join waits for thread completion")
    func handleJoinWaits() throws {
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

    @Test("Handle.isCurrent returns false from main thread")
    func isCurrentFalseFromMain() throws {
        let handle = try Kernel.Thread.spawn {
            // Do nothing
        }

        // From main thread, isCurrent should be false
        #expect(handle.isCurrent == false)

        handle.join()
    }
}

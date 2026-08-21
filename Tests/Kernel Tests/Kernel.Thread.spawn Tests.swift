import Kernel
import Kernel_Test_Support
import Synchronization
import Testing

extension Kernel.Thread.Spawn {
    enum Test {
        @Suite(.serialized) struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Kernel.Thread.Spawn.Test.Unit {
    @Test
    func `spawn creates thread that executes body`() throws {
        let executed = Atomic<Bool>(false)
        let handle = try Kernel.Thread.spawn {
            executed.store(true, ordering: .releasing)
        }
        try handle.join()
        #expect(executed.load(ordering: .acquiring) == true)
    }

    @Test
    func `spawn with value transfers ownership`() throws {
        let receivedValue = Atomic<Int>(0)
        let handle = try Kernel.Thread.spawn(42) { value in
            receivedValue.store(value, ordering: .releasing)
        }
        try handle.join()
        #expect(receivedValue.load(ordering: .acquiring) == 42)
    }

    @Test
    func `Handle.join waits for thread completion`() throws {
        let completed = Atomic<Bool>(false)
        let handle = try Kernel.Thread.spawn {

            for _ in 0..<1000 {
                _ = 1 + 1
            }
            completed.store(true, ordering: .releasing)
        }

        try handle.join()
        #expect(completed.load(ordering: .acquiring) == true)
    }

    @Test
    func `Handle.isCurrent returns false from main thread`() throws {
        let handle = try Kernel.Thread.spawn {

        }

        #expect(handle.isCurrent == false)

        try handle.join()
    }
}

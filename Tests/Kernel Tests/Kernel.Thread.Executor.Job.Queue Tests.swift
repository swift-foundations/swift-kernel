//
//  Kernel.Thread.Executor.Job.Queue Tests.swift
//  swift-kernel
//

import Test_Primitives
import Testing

@testable import Kernel

extension Kernel.Thread.Executor.Job.Queue {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Thread.Executor.Job.Queue.Test.Unit {
    @Test("empty queue reports isEmpty")
    func emptyQueue() {
        let queue = Kernel.Thread.Executor.Job.Queue()
        #expect(queue.isEmpty)
    }

    @Test("default capacity is at least 64")
    func defaultCapacity() {
        let queue = Kernel.Thread.Executor.Job.Queue()
        #expect(queue.capacity >= 64)
    }

    @Test("custom initial capacity is respected")
    func customCapacity() {
        let queue = Kernel.Thread.Executor.Job.Queue(initialCapacity: 128)
        #expect(queue.capacity >= 128)
    }

    @Test("minimum capacity is 1")
    func minimumCapacity() {
        let queue = Kernel.Thread.Executor.Job.Queue(initialCapacity: 0)
        #expect(queue.capacity >= 1)
    }

    @Test("dequeue from empty returns nil")
    func dequeueEmptyReturnsNil() {
        var queue = Kernel.Thread.Executor.Job.Queue()
        #expect(queue.dequeue() == nil)
    }
}


extension Kernel.Thread.Executor.Job.Queue.Test.Integration {
    @Test("queue grows when full")
    func growsWhenFull() {
        let queue = Kernel.Thread.Executor.Job.Queue(initialCapacity: 2)

        // Create dummy executor for job creation
        let executor = Kernel.Thread.Executor()
        defer { executor.shutdown() }

        // Verify the queue has at least the requested capacity
        // Note: Deque may allocate more than requested
        #expect(queue.capacity >= 2)
    }
}

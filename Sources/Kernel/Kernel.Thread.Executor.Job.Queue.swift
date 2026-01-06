//
//  Kernel.Thread.Executor.Job.Queue.swift
//  swift-kernel
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

extension Kernel.Thread.Executor.Job {
    /// Unbounded queue for executor jobs.
    ///
    /// O(1) enqueue and dequeue. Grows automatically when full.
    ///
    /// ## Thread Safety
    /// All access must be protected by `Synchronization`.
    struct Queue {
        private var storage: Deque<Kernel.Thread.Executor.Job>

        init(initialCapacity: Int = 64) {
            self.storage = Deque()
            storage.reserve(initialCapacity)
        }
    }
}

extension Kernel.Thread.Executor.Job.Queue {
    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }
    var capacity: Int { storage.capacity }
}

extension Kernel.Thread.Executor.Job.Queue {
    /// Enqueue a job. Grows the buffer if needed.
    mutating func enqueue(_ job: Kernel.Thread.Executor.Job) {
        storage.push.back(job)
    }

    /// Dequeue a job, or nil if empty.
    mutating func dequeue() -> Kernel.Thread.Executor.Job? {
        storage.take.front
    }
}

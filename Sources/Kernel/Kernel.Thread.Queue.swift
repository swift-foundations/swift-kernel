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

extension Kernel.Thread {
    /// A FIFO queue for use under external synchronization.
    ///
    /// This queue provides no internal locking - all access must be
    /// protected by an external `Synchronization` or `Mutex`.
    ///
    /// Uses ring buffer for O(1) enqueue/dequeue with geometric growth.
    ///
    /// ## Usage
    /// ```swift
    /// let sync = Kernel.Thread.Synchronization<1>()
    /// var queue = Kernel.Thread.Queue<Int>()
    ///
    /// sync.lock()
    /// queue.enqueue(42)
    /// if let value = queue.dequeue() {
    ///     // process value
    /// }
    /// sync.unlock()
    /// ```
    ///
    /// ## Thread Safety
    /// NOT thread-safe. All access must be protected by external synchronization.
    public struct Queue<Element> {
        private var storage: [Element?]
        private var head: Int = 0
        private var tail: Int = 0
        private var _count: Int = 0

        /// Creates a queue with the given initial capacity.
        ///
        /// - Parameter initialCapacity: Initial buffer size. Defaults to 64.
        public init(initialCapacity: Int = 64) {
            let capacity = max(initialCapacity, 1)
            self.storage = [Element?](repeating: nil, count: capacity)
        }

        /// Number of elements in the queue.
        public var count: Int { _count }

        /// Whether the queue is empty.
        public var isEmpty: Bool { _count == 0 }

        /// Current capacity of the queue.
        public var capacity: Int { storage.count }

        /// Enqueue an element. Grows the buffer if needed.
        ///
        /// - Parameter element: Element to add.
        /// - Complexity: O(1) amortized.
        public mutating func enqueue(_ element: Element) {
            if _count >= storage.count {
                grow()
            }
            storage[tail] = element
            tail = (tail + 1) % storage.count
            _count += 1
        }

        /// Dequeue an element, or nil if empty.
        ///
        /// - Returns: The front element, or nil if the queue is empty.
        /// - Complexity: O(1).
        public mutating func dequeue() -> Element? {
            guard _count > 0 else { return nil }
            let element = storage[head]
            storage[head] = nil
            head = (head + 1) % storage.count
            _count -= 1
            return element
        }

        /// Peek at the front element without removing it.
        ///
        /// - Returns: The front element, or nil if the queue is empty.
        public func peek() -> Element? {
            guard _count > 0 else { return nil }
            return storage[head]
        }

        /// Remove all elements from the queue.
        public mutating func removeAll(keepingCapacity: Bool = false) {
            if keepingCapacity {
                for i in 0..<storage.count {
                    storage[i] = nil
                }
            } else {
                storage = [Element?](repeating: nil, count: 1)
            }
            head = 0
            tail = 0
            _count = 0
        }

        /// Double the capacity and rehash existing elements.
        private mutating func grow() {
            let oldCapacity = storage.count
            let newCapacity = oldCapacity * 2
            var newStorage = [Element?](repeating: nil, count: newCapacity)

            // Copy elements in order from head to tail
            for i in 0..<_count {
                newStorage[i] = storage[(head + i) % oldCapacity]
            }

            storage = newStorage
            head = 0
            tail = _count
        }
    }
}

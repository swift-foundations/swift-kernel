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
    /// Uses `Deque` internally for O(1) enqueue/dequeue with automatic growth.
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
        private var storage: Deque<Element>

        /// Creates a queue with the given initial capacity.
        ///
        /// - Parameter initialCapacity: Initial buffer size. Defaults to 64.
        public init(initialCapacity: Int = 64) {
            self.storage = Deque()
            storage.reserve(initialCapacity)
        }

        /// Number of elements in the queue.
        public var count: Int { storage.count }

        /// Whether the queue is empty.
        public var isEmpty: Bool { storage.isEmpty }

        /// Current capacity of the queue.
        public var capacity: Int { storage.capacity }

        /// Enqueue an element. Grows the buffer if needed.
        ///
        /// - Parameter element: Element to add.
        /// - Complexity: O(1) amortized.
        public mutating func enqueue(_ element: Element) {
            storage.push.back(element)
        }

        /// Dequeue an element, or nil if empty.
        ///
        /// - Returns: The front element, or nil if the queue is empty.
        /// - Complexity: O(1).
        public mutating func dequeue() -> Element? {
            storage.take.front
        }

        /// Peek at the front element without removing it.
        ///
        /// - Returns: The front element, or nil if the queue is empty.
        public func peek() -> Element? {
            storage.peek.front
        }

        /// Remove all elements from the queue.
        public mutating func removeAll(keepingCapacity: Bool = false) {
            storage.removeAll(keepingCapacity: keepingCapacity)
        }
    }
}

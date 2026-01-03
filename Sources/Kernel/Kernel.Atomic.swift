// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// Memory ordering helpers for shared-memory synchronization.
    ///
    /// These helpers provide memory barriers for coordinating access to
    /// shared memory regions (e.g., io_uring ring buffers, lock-free queues).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Read with acquire semantics (see producer's writes)
    /// let tail = Kernel.Atomic.load(cqTailPtr, ordering: .acquiring)
    ///
    /// // Write with release semantics (producer's writes visible)
    /// Kernel.Atomic.store(sqTailPtr, newTail, ordering: .releasing)
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// These helpers are designed for single-producer/single-consumer scenarios
    /// where memory ordering (not atomicity) is the primary concern.
    public enum Atomic {}
}

// MARK: - Load Ordering

extension Kernel.Atomic {
    /// Memory ordering for atomic loads.
    public enum Load {
        /// Ordering semantics for load operations.
        public enum Ordering: Sendable {
            /// No ordering guarantees.
            case relaxed

            /// Acquire semantics: subsequent reads/writes cannot be reordered before this load.
            case acquiring
        }
    }

    /// Performs a load with the specified memory ordering.
    ///
    /// - Parameters:
    ///   - pointer: The memory location to load from.
    ///   - ordering: The memory ordering for the load.
    /// - Returns: The value at the memory location.
    @inline(__always)
    public static func load<T>(
        _ pointer: UnsafeMutablePointer<T>,
        ordering: Load.Ordering
    ) -> T {
        switch ordering {
        case .relaxed:
            return pointer.pointee
        case .acquiring:
            let value = pointer.pointee
            _compilerBarrier(value)
            return value
        }
    }
}

// MARK: - Store Ordering

extension Kernel.Atomic {
    /// Memory ordering for atomic stores.
    public enum Store {
        /// Ordering semantics for store operations.
        public enum Ordering: Sendable {
            /// No ordering guarantees.
            case relaxed

            /// Release semantics: prior reads/writes cannot be reordered after this store.
            case releasing
        }
    }

    /// Performs a store with the specified memory ordering.
    ///
    /// - Parameters:
    ///   - pointer: The memory location to store to.
    ///   - value: The value to store.
    ///   - ordering: The memory ordering for the store.
    @inline(__always)
    public static func store<T>(
        _ pointer: UnsafeMutablePointer<T>,
        _ value: T,
        ordering: Store.Ordering
    ) {
        switch ordering {
        case .relaxed:
            pointer.pointee = value
        case .releasing:
            _compilerBarrier(value)
            pointer.pointee = value
        }
    }
}

// MARK: - Compiler Barrier

extension Kernel.Atomic {
    /// Compiler barrier to prevent reordering.
    ///
    /// This function prevents the compiler from reordering memory operations
    /// across the barrier. On ARM64, the Swift compiler generates appropriate
    /// barrier instructions.
    ///
    /// - Note: This is a compiler barrier, not a hardware memory fence.
    ///   For single-producer/single-consumer scenarios with proper data
    ///   dependencies, this is sufficient.
    @inline(__always)
    @usableFromInline
    @_optimize(none)
    internal static func _compilerBarrier<T>(_ value: T) {
        // The @_optimize(none) attribute prevents the compiler from
        // optimizing away or reordering operations around this call
    }
}

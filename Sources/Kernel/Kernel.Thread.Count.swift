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

public import Dimension_Primitives

extension Kernel.Thread {
    /// Type-safe count of threads.
    ///
    /// Used for configuration of thread pools and executors.
    public typealias Count = Tagged<Kernel.Thread, Int>
}

extension Kernel.Thread.Count {
    /// Creates a thread count from a processor count.
    @inlinable
    public init(_ processorCount: Kernel.System.Processor.Count) {
        self.init(Int(processorCount))
    }
}

extension Int {
    /// Creates an Int from a thread count.
    @inlinable
    public init(_ count: Kernel.Thread.Count) {
        self = count.rawValue
    }
}

//
//  Kernel.Thread.Executors.Options.swift
//  swift-kernel
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

extension Kernel.Thread.Executors {
    /// Configuration options for the executor pool.
    public struct Options: Sendable {
        /// Number of executor threads in the pool.
        public var count: Kernel.Thread.Count

        /// Creates options with the specified thread count.
        ///
        /// - Parameter count: Number of threads. If nil, defaults to min(4, processorCount).
        public init(count: Kernel.Thread.Count? = nil) {
            self.count =
                count
                ?? Kernel.Thread.Count.min(
                    try! Kernel.Thread.Count(4),
                    Kernel.System.Processor.count.retag(Kernel.Thread.self)
                )
        }
    }
}

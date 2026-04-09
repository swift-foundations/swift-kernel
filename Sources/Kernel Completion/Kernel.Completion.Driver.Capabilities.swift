//
//  Kernel.Completion.Driver.Capabilities.swift
//  swift-kernel
//
//  Metadata describing the capabilities of a completion backend.
//

extension Kernel.Completion.Driver {
    /// Capabilities of a completion backend.
    public struct Capabilities: Sendable {
        /// Maximum submissions per flush cycle.
        public let ringSize: Int

        /// Whether the backend supports multishot operations
        /// (one submission producing multiple completions).
        public let multishot: Bool

        /// Whether the backend supports kernel-managed buffer pools
        /// (provided buffer groups).
        public let providedBuffers: Bool

        public init(
            ringSize: Int,
            multishot: Bool = false,
            providedBuffers: Bool = false
        ) {
            self.ringSize = ringSize
            self.multishot = multishot
            self.providedBuffers = providedBuffers
        }
    }
}

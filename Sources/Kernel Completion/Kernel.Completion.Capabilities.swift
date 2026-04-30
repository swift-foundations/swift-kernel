//
//  Kernel.Completion.Capabilities.swift
//  swift-kernel-primitives
//
//  Semantic feature flags for a completion backend.
//


extension Kernel.Completion {
    /// Semantic feature flags for a completion backend.
    ///
    /// Contains only cross-platform semantic capabilities that higher layers
    /// meaningfully branch on. Instance configuration details (ring size,
    /// queue depth) are NOT capabilities — they are internal to the backend.
    ///
    /// Lives on ``Completion``, not ``Driver``, because capabilities describe
    /// the resource instance, not the witness recipe.
    public struct Capabilities: Sendable {
        /// Whether the backend supports multishot operations
        /// (one submission producing multiple completions).
        ///
        /// When `true`, the consumer may submit multishot accept/recv
        /// operations and must track the ``Event/Flags/more`` flag to
        /// determine token lifecycle.
        public let multishot: Bool

        /// Whether the backend supports kernel-managed buffer pools
        /// (provided buffer groups).
        ///
        /// When `true`, the consumer may register buffer rings and submit
        /// operations with `.bufferSelect` to let the kernel choose buffers
        /// at completion time.
        ///
        /// - Note: Provisional. Subject to removal if no cross-platform
        ///   equivalent emerges (IOCP has no direct analog).
        public let providedBuffers: Bool

        public init(
            multishot: Bool = false,
            providedBuffers: Bool = false
        ) {
            self.multishot = multishot
            self.providedBuffers = providedBuffers
        }
    }
}

//
//  Kernel.Completion.Event.swift
//  swift-kernel-primitives
//
//  Raw completion event from the kernel ring.
//
//  Platform-agnostic value type. The consuming layer (swift-io)
//  interprets token to match continuations and result to
//  determine success/failure.
//

extension Kernel.Completion {
    /// A completion event harvested from the kernel.
    ///
    /// Copyable value type — no owned resources at this layer.
    /// The IO layer wraps this into richer types with outcome
    /// enums and ~Copyable descriptor transfer.
    public struct Event: Sendable {
        /// Matches the submission's token — used by the consumer
        /// to correlate completions with in-flight operations.
        public let token: Kernel.Completion.Token

        /// Operation result.
        public let result: Kernel.Completion.Event.Result

        /// Platform-specific completion flags.
        public let flags: Kernel.Completion.Event.Flags

        public init(
            token: Kernel.Completion.Token,
            result: Kernel.Completion.Event.Result,
            flags: Kernel.Completion.Event.Flags = []
        ) {
            self.token = token
            self.result = result
            self.flags = flags
        }
    }
}

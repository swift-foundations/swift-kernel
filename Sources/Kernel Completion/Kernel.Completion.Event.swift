//
//  Kernel.Completion.Event.swift
//  swift-kernel
//
//  Raw completion event from the kernel ring.
//
//  Platform-agnostic value type. The consuming layer (swift-io)
//  interprets userData to match continuations and result to
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
        public let token: Token

        /// Operation result.
        public let result: Result

        /// Platform-specific completion flags.
        public let flags: Flags

        public init(
            token: Token,
            result: Result,
            flags: Flags = .none
        ) {
            self.token = token
            self.result = result
            self.flags = flags
        }
    }
}

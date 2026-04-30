//
//  Kernel.Completion.Event.Flags.swift
//  swift-kernel-primitives
//
//  Cross-platform completion event flags.
//


extension Kernel.Completion.Event {
    /// Completion event flags carrying cross-platform semantic information.
    ///
    /// The backend normalizes platform-specific flags into this `OptionSet`.
    /// Callers inspect flags to determine multishot lifecycle and other
    /// delivery-mode semantics.
    ///
    /// Named flags (``more``) are the intended public API. Raw construction
    /// is available per Swift `OptionSet` convention but not encouraged.
    public struct Flags: OptionSet, Sendable, Hashable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// More completions will follow for the same submission token.
        ///
        /// When present, the originating submission remains active and will
        /// produce additional completion events. When absent on a completion
        /// for a multishot submission, this is the terminal event — the token
        /// is no longer active.
        ///
        /// Single-shot submissions never set this flag.
        public static let more = Flags(rawValue: 1 << 0)
    }
}

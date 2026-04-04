//
//  Kernel.Readiness.Driver.Capabilities.swift
//  swift-kernel
//
//  Metadata describing the capabilities of a readiness backend.
//

extension Kernel.Readiness.Driver {
    /// Capabilities of a readiness backend.
    public struct Capabilities: Sendable {
        /// Maximum number of events returned per poll cycle.
        public let maximum: Int

        /// The event triggering mode.
        ///
        /// - `.edge`: fires once per state transition (kqueue `EV_CLEAR`, epoll `EPOLLET`)
        /// - `.level`: fires as long as the condition holds
        public let triggering: Triggering

        public init(maximum: Int, triggering: Triggering) {
            self.maximum = maximum
            self.triggering = triggering
        }

        /// Event triggering mode.
        public enum Triggering: Sendable {
            /// Edge-triggered: fires once per state transition.
            case edge
            /// Level-triggered: fires as long as the condition holds.
            case level
        }
    }
}

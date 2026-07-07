//
//  Kernel.Completion.Submission.Flags.swift
//  swift-kernel-primitives
//
//  Platform-agnostic submission flags (shell).
//
//  The consumer sets intent via typed flags. The driver backend
//  maps to platform-specific flag values. Constants are added
//  by the platform layer via extension (shell + values pattern).
//

extension Kernel.Completion.Submission {
    /// Flags controlling submission behavior.
    ///
    /// These express platform-agnostic intent. The driver backend
    /// maps each flag to the platform-specific value.
    ///
    /// This is the empty shell — platform layers add constants
    /// via extension per [PLAT-ARCH-013].
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
    }
}

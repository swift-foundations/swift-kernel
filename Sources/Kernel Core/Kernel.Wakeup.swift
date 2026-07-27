//
//  Kernel.Wakeup.swift
//  swift-kernel
//
//  Cross-platform vocabulary for the wakeup mechanism that interrupts
//  blocking event waits. Used by both Readiness (reactor) and Completion
//  (proactor) drivers.
//
//  Hosted at L3-unifier swift-kernel per [PLAT-ARCH-008c] (cross-platform
//  vocabulary belongs at L3, not at L2 spec packages). Relocated from
//  iso-9945 L2 in Tier 5-Wakeup (post-Path-X envelope, 2026-05-02);
//  L2 platform constructors at swift-linux-standard / swift-darwin-standard
//  expose typed `@Sendable () -> Void` signal closures that L3 site-of-use
//  callers wrap into `Channel(signal:)` per [PLAT-ARCH-008j] (raw fd
//  capture stays at L2).
//

extension Kernel {
    /// Wakeup mechanism for interrupting blocking event waits.
    public enum Wakeup {}
}

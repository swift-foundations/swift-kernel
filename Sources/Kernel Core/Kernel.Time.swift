// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Kernel.Time chain (no L3-unifier declaration; canonical at L2 per [PLAT-ARCH-005])
//
// `Kernel.Time` resolves via the L3-unifier → L3-policy → L2 → L1 typealias chain:
//
//   Kernel.Time (swift-kernel L3-unifier, via `Kernel = POSIX.Kernel` typealias)
//     → POSIX.Kernel.Time (swift-posix L3-policy, Wave 3.5-Corrective-4)
//       → ISO_9945.Kernel.Time (swift-iso-9945 L2, canonical per [PLAT-ARCH-005] L2-canonical-where-spec-layer-exists)
//         → Instant (swift-time-primitives L1)
//
// No `extension Kernel { typealias Time = Instant }` at this L3-unifier file —
// declaring it here would be a redundant typealias on the same parent
// (`POSIX.Kernel` post-Final-Atomic flip) as swift-posix's
// `extension POSIX.Kernel { typealias Time = ISO_9945.Kernel.Time }`,
// triggering the [PLAT-ARCH-018] silent typealias-conflict pattern.
//
// Tier 5-Time (post-Path-X envelope, 2026-05-02) deduplicated the prior
// triple-declaration (swift-kernel L3-unifier + iso-9945 L2 G6.A mirror +
// swift-posix L3-policy Corrective-4 chain) by removing the L3-unifier
// declaration. Aligns with the Wave 4c-Socket Prerequisite II three-tier
// composition restoration for Descriptor: L3-unifier composes its peer
// L3-policy tier; never re-declares typealiases the chain already resolves.

// MARK: - Kernel API Compatibility (package-internal)
//
// Convenience initializers and accessors on `Instant` for swift-kernel
// internal callers that work in `(seconds, nanoseconds)` decomposition
// rather than `Instant`'s native `(secondsSinceUnixEpoch, nanosecondFraction)`
// shape. Typed as `package` extensions on `Instant` (the L1 canonical type) —
// these are NOT part of the cross-platform `Kernel.Time` chain documented
// above, but supporting infrastructure for kernel-internal time arithmetic.

extension Instant {
    /// Creates a time value (unchecked kernel API).
    ///
    /// - Parameters:
    ///   - seconds: Seconds since the Unix epoch.
    ///   - nanoseconds: Nanoseconds (0-999,999,999).
    @inlinable
    package init(seconds: Int64, nanoseconds: Int32) {
        self.init(
            _unchecked: (),
            secondsSinceUnixEpoch: seconds,
            nanosecondFraction: nanoseconds
        )
    }

    /// Creates a time value from seconds only (no nanoseconds).
    @inlinable
    package init(seconds: Int64) {
        self.init(seconds: seconds, nanoseconds: 0)
    }

    /// Seconds since the Unix epoch (alias for `secondsSinceUnixEpoch`).
    @inlinable
    package var seconds: Int64 { secondsSinceUnixEpoch }

    /// Nanoseconds (alias for `nanosecondFraction`).
    @inlinable
    package var nanoseconds: Int32 { nanosecondFraction }

    /// Total time in nanoseconds since the Unix epoch.
    @inlinable
    package var totalNanoseconds: Int64 {
        secondsSinceUnixEpoch * 1_000_000_000 + Int64(nanosecondFraction)
    }

    /// Creates a time value from total nanoseconds since the Unix epoch.
    @inlinable
    package init(totalNanoseconds: Int64) {
        self.init(
            seconds: totalNanoseconds / 1_000_000_000,
            nanoseconds: Int32(totalNanoseconds % 1_000_000_000)
        )
    }
}

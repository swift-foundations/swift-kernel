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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)

public import Kernel_Random_Primitives

// MARK: - Cross-platform Random surface on POSIX
//
// Delegates directly to the L2 raw wrapper on each platform:
// - Darwin: ``Darwin/Kernel/Random/arc4random(_:)`` (swift-darwin-standard).
//   `arc4random_buf` is infallible; `throws(Kernel.Random.Error)` is present
//   for cross-platform signature parity per [PATTERN-009] — the body never
//   throws on Darwin.
// - Linux: ``Linux/Kernel/Random/getrandom(_:)`` (swift-linux-standard).
//   `getrandom(2)` may throw on EAGAIN (entropy pool not ready); EINTR retry
//   is handled inside the L2 wrapper.
//
// The [PLAT-ARCH-008e] "L3 unifier composes over L3 platform-policy tier"
// discipline applies in spirit: no L3 platform-policy wrapper exists for
// `Kernel.Random` at the per-platform layer (random generation is not EINTR-
// sensitive in the normal case — Linux's single-shot retry lives inside the
// L2 raw wrapper, not in a policy tier), so the unifier delegates to L2 raw
// directly. This matches the rule's "when the L3 platform tier is empty, the
// unifier MAY delegate to L2 raw directly" exception.

extension Kernel.Random {
    /// Fills a buffer with cryptographically secure random bytes.
    ///
    /// Cross-platform entry point for random generation. Consumers write
    /// `try Kernel.Random.fill(buffer)` on any platform; the implementation
    /// dispatches per platform:
    ///
    /// - **Darwin**: ``Darwin/Kernel/Random/arc4random(_:)`` — `arc4random_buf`,
    ///   infallible. The `throws` annotation is present for signature parity.
    /// - **Linux**: ``Linux/Kernel/Random/getrandom(_:)`` — `getrandom(2)`
    ///   with partial-read and EINTR handling inside the L2 wrapper. May
    ///   throw `.wouldBlock` if the entropy pool is not ready.
    /// - **Windows**: ``Windows/Kernel/Random/bCryptGenRandom(_:)`` — CNG
    ///   `BCryptGenRandom`. (See the Windows-guarded companion file.)
    ///
    /// - Parameter buffer: The buffer to fill with random bytes.
    /// - Throws: ``Kernel/Random/Error`` on failure.
    @inlinable
    public static func fill(_ buffer: UnsafeMutableRawBufferPointer) throws(Kernel.Random.Error) {
        #if canImport(Darwin)
        try unsafe Darwin.Kernel.Random.arc4random(buffer)
        #else
        try unsafe Linux.Kernel.Random.getrandom(buffer)
        #endif
    }
}

#endif

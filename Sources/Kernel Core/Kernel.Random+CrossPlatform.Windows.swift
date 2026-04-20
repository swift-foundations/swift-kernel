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

#if os(Windows)

public import Kernel_Random_Primitives

// MARK: - Cross-platform Random surface on Windows
//
// Delegates directly to ``Windows/Kernel/Random/bCryptGenRandom(_:)`` in
// swift-windows-standard (L2). Windows has no EINTR and no L3 policy wrapper
// for random generation — the [PLAT-ARCH-008e] "L3 platform tier empty"
// exception applies.

extension Kernel.Random {
    /// Fills a buffer with cryptographically secure random bytes using
    /// `BCryptGenRandom` via the Windows CNG API.
    ///
    /// - Parameter buffer: The buffer to fill with random bytes.
    /// - Throws: ``Kernel/Random/Error`` on NTSTATUS failure.
    @inlinable
    public static func fill(_ buffer: UnsafeMutableRawBufferPointer) throws(Kernel.Random.Error) {
        try unsafe Windows.Kernel.Random.bCryptGenRandom(buffer)
    }
}

#endif

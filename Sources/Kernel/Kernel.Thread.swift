// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// Raw thread syscall wrappers.
    ///
    /// This namespace provides policy-free wrappers for platform thread primitives:
    /// - POSIX: `pthread_create`, `pthread_join`, `pthread_detach`
    /// - Windows: `CreateThread`, `WaitForSingleObject`, `CloseHandle`
    ///
    /// Higher layers (swift-io) build thread spawning APIs, ownership transfer,
    /// and lifecycle management on top of these primitives.
    public enum Thread {}
}

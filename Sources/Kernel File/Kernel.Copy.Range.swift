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

extension Kernel.Copy {
    /// Range-based copy operations.
    ///
    /// Enables efficient kernel-space copying between file descriptors,
    /// potentially using server-side copy for network filesystems.
    ///
    /// ## Platform Support
    ///
    /// | Platform | Mechanism | Implementation Package |
    /// |----------|-----------|------------------------|
    /// | Linux | `copy_file_range(2)` | `swift-kernel` |
    ///
    /// ## Platform Implementation
    ///
    /// Range copy operations are in platform-specific packages:
    /// - Linux: `swift-kernel` (`Kernel.Copy.Range.copy`)
    public enum Range {}
}

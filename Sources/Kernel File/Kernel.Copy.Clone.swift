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
    /// Clone operations (copy-on-write).
    ///
    /// Creates copy-on-write clones where supported, sharing data blocks
    /// until either file is modified.
    ///
    /// ## Platform Support
    ///
    /// | Platform | Mechanism | Implementation Package |
    /// |----------|-----------|------------------------|
    /// | Linux | `FICLONE` ioctl | `swift-kernel` |
    /// | macOS | `clonefile()` | `swift-kernel` |
    ///
    /// ## Platform Implementation
    ///
    /// Clone operations are in platform-specific packages:
    /// - Linux: `swift-kernel` (`Kernel.Copy.Clone.perform`)
    /// - macOS: `swift-kernel` (`Kernel.Copy.Clone.file`)
    public enum Clone {}
}

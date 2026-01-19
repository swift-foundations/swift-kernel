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

public import Kernel_Primitives

extension Kernel.File.Write {
    /// Atomic file writing with crash-safety guarantees.
    ///
    /// Provides crash-safe file writes using the standard pattern:
    ///   1. Write to a temporary file in the same directory
    ///   2. Sync the file to disk (fsync)
    ///   3. Atomically rename temp → destination
    ///   4. Sync the directory to ensure the rename is persisted
    ///
    /// This guarantees that on any crash or power failure, you either have:
    ///   - The complete new file, or
    ///   - The complete old file (or no file if it didn't exist)
    ///
    /// You never get a partial/corrupted file.
    public enum Atomic {}
}

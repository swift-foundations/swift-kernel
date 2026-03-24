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
    /// Streaming/chunked file writing with optional atomic guarantees.
    ///
    /// Memory-efficient for large files - only holds one chunk at a time.
    ///
    /// ## Atomic Mode (default)
    /// - Writes to a temporary file in the same directory
    /// - Syncs temp file according to durability setting
    /// - Atomically renames on completion
    /// - Syncs directory to persist the rename
    /// - Either complete new file or original state preserved on crash
    ///
    /// ## Direct Mode
    /// - Writes directly to destination
    /// - Faster but partial writes possible on crash
    ///
    /// ## Performance Note
    /// For optimal performance, provide chunks of 64KB–1MB. Smaller chunks work
    /// correctly but with higher overhead due to syscall frequency.
    public enum Streaming {}
}

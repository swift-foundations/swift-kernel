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

extension Kernel.File.Clone {
    /// The cloning capability of a filesystem/path.
    ///
    /// Capability is probed per-path because:
    /// - Different volumes may have different capabilities
    /// - The same process may work with multiple filesystems
    public enum Capability: Sendable, Equatable {
        /// The filesystem supports copy-on-write reflink.
        ///
        /// Cloning is O(1) regardless of file size.
        case reflink

        /// The filesystem does not support reflink.
        ///
        /// Only byte-by-byte copy is available.
        case none
    }

    /// The behavior policy for clone operations.
    public enum Behavior: Sendable, Equatable {
        /// Attempt reflink only; fail if unsupported.
        ///
        /// Use when you require zero-copy semantics (e.g., for correctness
        /// in snapshot scenarios where sharing storage is intentional).
        case reflinkOrFail

        /// Attempt reflink; fall back to byte-by-byte copy if unsupported.
        ///
        /// This is the practical choice for portable code that wants
        /// best-effort performance optimization.
        case reflinkOrCopy

        /// Skip reflink attempt; always copy bytes.
        ///
        /// Use when you explicitly need independent storage
        /// (e.g., the destination will be heavily modified).
        case copyOnly
    }

    /// Result of a clone operation.
    public enum Result: Sendable, Equatable {
        /// The file was cloned via reflink (zero-copy).
        case reflinked

        /// The file was copied byte-by-byte.
        case copied
    }
}

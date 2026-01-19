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

extension Kernel.File.Write.Streaming {
    /// Options controlling streaming write behavior.
    public struct Options: Sendable {
        /// How to commit chunks to disk.
        public var commit: Commit.Policy

        /// Create intermediate directories if they don't exist.
        ///
        /// When enabled, missing parent directories are created before writing.
        /// Note: Creating intermediates may traverse symlinks in path components.
        /// This is not hardened against symlink-based attacks.
        public var createIntermediates: Bool

        public init(
            commit: Commit.Policy = .atomic(.init()),
            createIntermediates: Bool = false
        ) {
            self.commit = commit
            self.createIntermediates = createIntermediates
        }
    }
}

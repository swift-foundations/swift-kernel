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

extension Kernel.File.Write.Atomic {
    /// Options controlling atomic write behavior.
    public struct Options: Sendable {
        public var strategy: Strategy
        public var durability: Durability
        public var preservePermissions: Bool
        public var preserveOwnership: Bool
        public var strictOwnership: Bool
        public var preserveTimestamps: Bool
        public var preserveExtendedAttributes: Bool
        public var preserveACLs: Bool

        /// Create intermediate directories if they don't exist.
        ///
        /// When enabled, missing parent directories are created before writing.
        /// Note: Creating intermediates may traverse symlinks in path components.
        /// This is not hardened against symlink-based attacks.
        public var createIntermediates: Bool

        public init(
            strategy: Strategy = .replaceExisting,
            durability: Durability = .full,
            preservePermissions: Bool = true,
            preserveOwnership: Bool = false,
            strictOwnership: Bool = false,
            preserveTimestamps: Bool = false,
            preserveExtendedAttributes: Bool = false,
            preserveACLs: Bool = false,
            createIntermediates: Bool = false
        ) {
            self.strategy = strategy
            self.durability = durability
            self.preservePermissions = preservePermissions
            self.preserveOwnership = preserveOwnership
            self.strictOwnership = strictOwnership
            self.preserveTimestamps = preserveTimestamps
            self.preserveExtendedAttributes = preserveExtendedAttributes
            self.preserveACLs = preserveACLs
            self.createIntermediates = createIntermediates
        }
    }
}

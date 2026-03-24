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

extension Kernel.File.Open {
    /// Configuration for opening a file.
    ///
    /// This bundles common open parameters into a convenient struct.
    /// Uses kernel types directly where possible.
    ///
    /// Note: This is distinct from `Kernel.File.Open.Options` which is
    /// an OptionSet for low-level flags.
    public struct Configuration: Sendable, Equatable {
        /// Access mode (read, write, or both).
        public var mode: Kernel.File.Open.Mode

        /// Create the file if it doesn't exist.
        public var create: Bool

        /// Truncate the file to zero length on open.
        public var truncate: Bool

        /// Cache mode (buffered, direct, uncached, or auto).
        public var cache: Kernel.File.Direct.Mode

        /// Creates default configuration (read-only, buffered).
        public init() {
            self.mode = .read
            self.create = false
            self.truncate = false
            self.cache = .buffered
        }

        /// Creates configuration with specific access mode.
        public init(mode: Kernel.File.Open.Mode) {
            self.mode = mode
            self.create = false
            self.truncate = false
            self.cache = .buffered
        }
    }
}

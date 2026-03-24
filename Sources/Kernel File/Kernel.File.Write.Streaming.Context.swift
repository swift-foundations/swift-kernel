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
    /// Context for multi-phase streaming writes.
    ///
    /// This struct holds the state needed for the open → write → commit flow.
    /// All fields are immutable after initialization.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let context = try Kernel.File.Write.Streaming.open(path: kernelPath, options: options)
    /// try Kernel.File.Write.Streaming.write(chunk: span, to: context)
    /// try Kernel.File.Write.Streaming.commit(context)
    /// ```
    ///
    /// ## Cleanup
    ///
    /// If an error occurs during write, call `cleanup(context)` to close the
    /// file descriptor and remove any temp file.
    ///
    /// ## Threading
    ///
    /// Context is `Sendable` but operations on it should be sequential.
    /// The descriptor and paths are stable after creation.
    public struct Context: Sendable {
        /// The file descriptor for the open file.
        public let descriptor: Kernel.Descriptor

        /// Path string for the temp file (nil for direct mode).
        ///
        /// In atomic mode, we write to a temp file first, then rename.
        /// In direct mode, we write directly to the destination.
        public let tempPathString: Swift.String?

        /// The resolved destination path string.
        public let resolvedPathString: Swift.String

        /// The parent directory path string (for directory sync).
        public let parentPathString: Swift.String

        /// The durability setting for this write.
        public let durability: Kernel.File.Write.Durability

        /// Whether this is an atomic write (temp file + rename).
        public let isAtomic: Bool

        /// The atomic strategy (nil for direct mode).
        public let strategy: Atomic.Strategy?

        public init(
            descriptor: Kernel.Descriptor,
            tempPathString: Swift.String?,
            resolvedPathString: Swift.String,
            parentPathString: Swift.String,
            durability: Kernel.File.Write.Durability,
            isAtomic: Bool,
            strategy: Atomic.Strategy?
        ) {
            self.descriptor = descriptor
            self.tempPathString = tempPathString
            self.resolvedPathString = resolvedPathString
            self.parentPathString = parentPathString
            self.durability = durability
            self.isAtomic = isAtomic
            self.strategy = strategy
        }
    }
}

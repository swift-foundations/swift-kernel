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

// MARK: - Configuration

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

// MARK: - High-Level Open API

extension Kernel.File {
    /// Opens a file and returns a handle.
    ///
    /// This is the primary entry point for opening files with automatic
    /// Direct I/O mode resolution and alignment requirement discovery.
    ///
    /// ## Threading
    /// This function is thread-safe. Multiple threads may call `open()` concurrently
    /// on different paths. Opening the same path from multiple threads is safe but
    /// results in independent file descriptors with separate file position state.
    ///
    /// ## Blocking Behavior
    /// This function performs blocking syscalls (`open(2)` / `CreateFileW`) and
    /// should not be called from Swift's cooperative thread pool. Use a dedicated
    /// executor or `Kernel.Thread.Executor` for file operations.
    ///
    /// ## Direct I/O Resolution
    /// When `configuration.cache` is `.auto`, this method probes the filesystem
    /// for Direct I/O support and alignment requirements. If Direct I/O is not
    /// supported, it falls back to buffered I/O silently.
    ///
    /// ## Error Conditions
    /// Throws `Kernel.File.Open.Error` which includes:
    /// - `.notFound` – Path does not exist (and `.create` not specified)
    /// - `.permission` – Insufficient permissions to open with requested mode
    /// - `.isDirectory` – Path is a directory (for regular file operations)
    /// - `.exists` – File exists and `.exclusive` was specified
    /// - `.tooManyOpen` – Process or system file descriptor limit reached
    /// - `.readOnly` – Filesystem is read-only and write access requested
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - configuration: Open configuration (mode, create, truncate, cache mode).
    /// - Returns: A file handle with Direct I/O state.
    /// - Throws: `Kernel.File.Open.Error` on failure.
    public static func open(
        _ path: borrowing Kernel.Path,
        configuration: Open.Configuration = .init()
    ) throws(Open.Error) -> Handle {
        // 1. Discover requirements
        let requirements = Direct.Requirements(path)

        // 2. Resolve cache mode
        let resolved: Direct.Mode.Resolved
        do {
            resolved = try configuration.cache.resolve(given: requirements)
        } catch {
            // Fall back to buffered if direct not supported
            resolved = .buffered
        }

        // 3. Build Kernel options
        var kernelOptions: Open.Options = []
        if configuration.create { kernelOptions.insert(.create) }
        if configuration.truncate { kernelOptions.insert(.truncate) }
        if resolved == .direct { kernelOptions.insert(.direct) }

        // 4. Open via Kernel primitives
        let descriptor = try Open.open(
            path: path,
            mode: configuration.mode,
            options: kernelOptions,
            permissions: .standard
        )

        return Handle(
            descriptor: descriptor,
            direct: resolved,
            requirements: requirements
        )
    }
}

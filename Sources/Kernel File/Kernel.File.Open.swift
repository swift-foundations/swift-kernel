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

public import Path_Primitives

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
        _ path: borrowing Path.Borrowed,
        configuration: Open.Configuration = .init()
    ) throws(Open.Error) -> Handle {
        // 1. Discover requirements
        let requirements = Direct.Requirements(path)

        // 2. Resolve cache mode
        let resolved: Direct.Mode.Resolved
        do throws(Kernel.File.Direct.Error) {
            resolved = try configuration.cache.resolve(given: requirements)
        } catch {
            // Fall back to buffered if direct not supported
            resolved = .buffered
        }

        // 3. Build Kernel options
        var kernelOptions: Open.Options = []
        if configuration.create { kernelOptions.insert(.create) }
        if configuration.truncate { kernelOptions.insert(.truncate) }
        #if os(Linux)
            if resolved == .direct { kernelOptions.insert(.direct) }
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if resolved == .direct { kernelOptions.insert(.noCache) }
        #endif

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

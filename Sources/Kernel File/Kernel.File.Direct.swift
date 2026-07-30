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

public import Path_Primitives
public import Memory_Primitives

/// Namespace for Direct I/O operations (cache bypass).
///
/// Direct I/O bypasses the operating system's page cache, allowing data to flow
/// directly between user buffers and storage. This is useful for:
/// - Database engines that manage their own caching
/// - Large sequential I/O where cache pollution is undesirable
/// - Applications requiring predictable latency
///
/// ## Platform Semantics
///
/// | Platform | Flag | Semantics | Alignment Required |
/// |----------|------|-----------|-------------------|
/// | Linux | `O_DIRECT` | Strict bypass | Yes (buffer, offset, length) |
/// | Windows | `FILE_FLAG_NO_BUFFERING` | Strict bypass | Yes (sector-aligned) |
/// | macOS | `fcntl(F_NOCACHE)` | Best-effort hint | No |
///
/// **Important:** macOS `F_NOCACHE` is a *hint*, not a strict bypass. The kernel
/// may still cache data. Use `.uncached` mode on macOS, not `.direct`.
///
/// This vocabulary is Institute-defined cross-platform policy, unified at L3;
/// the underlying syscalls (`O_DIRECT`, `FILE_FLAG_NO_BUFFERING`, `F_NOCACHE`)
/// are implemented by swift-linux-standard, swift-darwin-standard, and
/// swift-windows-32.
extension Kernel.File {
    public enum Direct {}
}

// MARK: - Public Requirements API

extension Kernel.File.Direct {
    /// Queries alignment requirements for a file path.
    ///
    /// Use this to determine whether Direct I/O is available and what
    /// alignment constraints apply before opening a file.
    ///
    /// ## Platform Behavior
    ///
    /// - **macOS**: Always returns `.unknown(.platformUnsupported)` because
    ///   `F_NOCACHE` has no alignment requirements.
    /// - **Linux**: Returns `.unknown(.sectorSizeUndetermined)` because
    ///   alignment constraints are not reliably discoverable.
    /// - **Windows**: Returns `.known(...)` based on sector size from
    ///   `GetDiskFreeSpaceW`, or `.unknown` for network paths.
    ///
    /// - Parameter path: The file path to query.
    /// - Returns: The alignment requirements, or `.unknown` with a reason.
    public static func requirements(
        for path: borrowing Path
    ) -> Requirements {
        #if os(macOS)
            return .unknown(reason: .platformUnsupported)
        #elseif os(Linux)
            return .unknown(reason: .sectorSizeUndetermined)
        #elseif os(Windows)
            return .known(Requirements.Alignment(uniform: .`4096`))
        #else
            return .unknown(reason: .platformUnsupported)
        #endif
    }
}

// MARK: - Requirements Constructors

extension Kernel.File.Direct.Requirements {
    /// Creates known alignment requirements with explicit values.
    ///
    /// Use this when you know the specific alignment requirements for your
    /// storage configuration. This bypasses automatic discovery and allows
    /// Direct I/O on platforms where discovery fails.
    ///
    /// - Parameters:
    ///   - bufferAlignment: Required alignment for buffer addresses.
    ///   - offsetAlignment: Required alignment for file offsets.
    ///   - lengthMultiple: Required multiple for I/O lengths.
    public init(
        bufferAlignment: Memory.Alignment,
        offsetAlignment: Memory.Alignment,
        lengthMultiple: Memory.Alignment
    ) {
        self = .known(
            Alignment(
                bufferAlignment: bufferAlignment,
                offsetAlignment: offsetAlignment,
                lengthMultiple: lengthMultiple
            )
        )
    }

    /// Creates known alignment requirements with a uniform value.
    ///
    /// Convenience for when buffer, offset, and length all use the same alignment.
    ///
    /// - Parameter alignment: The uniform alignment value.
    public init(uniformAlignment alignment: Memory.Alignment) {
        self = .known(Alignment(uniform: alignment))
    }
}

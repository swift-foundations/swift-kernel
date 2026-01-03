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

/// Namespace for file cloning (copy-on-write reflink) operations.
///
/// File cloning creates a lightweight copy that shares storage with the original
/// until either file is modified. This is significantly faster than a byte-by-byte
/// copy for large files on supported filesystems.
///
/// ## Platform Support
///
/// | Platform | Filesystem | Mechanism |
/// |----------|------------|-----------|
/// | macOS | APFS | `clonefile()` |
/// | Linux | Btrfs, XFS | `ioctl(FICLONE)` |
/// | Linux | Any | `copy_file_range()` (may CoW) |
/// | Windows | ReFS | `FSCTL_DUPLICATE_EXTENTS_TO_FILE` |
///
/// ## Usage
///
/// ```swift
/// // Clone with fallback to copy
/// try Kernel.File.Clone.clone(
///     from: sourcePath,
///     to: destinationPath,
///     behavior: .reflinkOrCopy
/// )
///
/// // Probe capability first
/// let cap = try Kernel.File.Clone.capability(at: sourcePath)
/// if cap == .reflink {
///     try Kernel.File.Clone.clone(from: sourcePath, to: destinationPath, behavior: .reflinkOrFail)
/// }
/// ```
extension Kernel.File {
    public enum Clone {}
}

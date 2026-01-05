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

public import SystemPackage

extension Kernel.File.Direct {
    /// Alignment requirements for Direct I/O operations.
    ///
    /// Direct I/O on Linux and Windows requires strict alignment of:
    /// - Buffer memory address
    /// - File offset
    /// - I/O transfer length
    ///
    /// Requirements are discovered at runtime because they depend on:
    /// - The underlying storage device's sector size
    /// - Filesystem constraints
    /// - Volume configuration
    ///
    /// ## Known vs Unknown
    ///
    /// Requirements are modeled as either `.known` (we have concrete values)
    /// or `.unknown` (we cannot determine requirements reliably).
    ///
    /// **Critical invariant:** `.direct` mode requires `.known` requirements.
    /// If requirements are `.unknown`, Direct I/O is `.notSupported`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let req = try handle.direct.requirements()
    /// switch req {
    /// case .known(let alignment):
    ///     // Safe to use .direct mode
    ///     var buffer = try Buffer.Aligned(
    ///         byteCount: 4096,
    ///         alignment: alignment.bufferAlignment
    ///     )
    ///     try handle.read(into: &buffer, at: 0)
    ///
    /// case .unknown(let reason):
    ///     // Cannot use .direct mode safely
    ///     // Fall back to .buffered or use .auto(policy: .fallbackToBuffered)
    /// }
    /// ```
    public enum Requirements: Sendable, Equatable {
        /// Alignment requirements are known and can be satisfied.
        case known(Alignment)

        /// Alignment requirements could not be determined.
        ///
        /// Direct I/O is not supported when requirements are unknown.
        /// Use `.buffered` mode or `.auto(policy: .fallbackToBuffered)`.
        case unknown(reason: Reason)
    }
}

// MARK: - Platform-Specific Initialization

#if os(macOS)
    extension Kernel.File.Direct.Requirements {
        /// Creates requirements for a path.
        ///
        /// On macOS, true Direct I/O is not supported. Only `.uncached` mode
        /// (F_NOCACHE hint) is available, which has no alignment requirements.
        public init(_ path: FilePath) {
            self = .unknown(reason: .platformUnsupported)
        }
    }
#endif

#if os(Linux)
    internal import Glibc

    extension Kernel.File.Direct.Requirements {
        /// Creates requirements for a path.
        ///
        /// On Linux, O_DIRECT alignment constraints are not reliably discoverable.
        /// Returns `.unknown` to fail closed. Callers should use
        /// `.auto(.fallbackToBuffered)` for best-effort operation.
        public init(_ path: FilePath) {
            // Linux O_DIRECT alignment is not reliably discoverable.
            // statfs.f_bsize is the optimal transfer size, NOT the alignment requirement.
            // Actual requirements depend on device sector size, filesystem, and driver.
            self = .unknown(reason: .sectorSizeUndetermined)
        }
    }
#endif

#if os(Windows)
    public import WinSDK

    extension Kernel.File.Direct.Requirements {
        /// Creates requirements for a path.
        ///
        /// Uses GetDiskFreeSpaceW to determine sector size.
        /// This is the minimal safe alignment for FILE_FLAG_NO_BUFFERING.
        public init(_ path: FilePath) {
            // Extract the root path (e.g., "C:\" from "C:\Users\...")
            guard let rootPath = Self.extractRootPath(from: path.string) else {
                self = .unknown(reason: .sectorSizeUndetermined)
                return
            }

            var sectorsPerCluster: DWORD = 0
            var bytesPerSector: DWORD = 0
            var numberOfFreeClusters: DWORD = 0
            var totalNumberOfClusters: DWORD = 0

            let result = rootPath.withCString(encodedAs: UTF16.self) { root in
                GetDiskFreeSpaceW(
                    root,
                    &sectorsPerCluster,
                    &bytesPerSector,
                    &numberOfFreeClusters,
                    &totalNumberOfClusters
                )
            }

            guard result, bytesPerSector > 0 else {
                self = .unknown(reason: .sectorSizeUndetermined)
                return
            }

            // Use the bytes per sector as alignment, falling back to 4096 for non-standard sizes
            let alignment: Binary.Alignment = bytesPerSector == 512 ? .`512` : .`4096`
            self = .known(Alignment(uniform: alignment))
        }

        /// Extracts the root path from a file path.
        private static func extractRootPath(from path: String) -> String? {
            // Handle UNC paths
            if path.hasPrefix("\\\\") {
                let components = path.dropFirst(2).split(separator: "\\", maxSplits: 2)
                if components.count >= 2 {
                    return "\\\\" + components[0] + "\\" + components[1] + "\\"
                }
                return nil
            }

            // Handle extended-length paths
            if path.hasPrefix("\\\\?\\") {
                let rest = path.dropFirst(4)
                if rest.count >= 2 && rest.dropFirst().hasPrefix(":") {
                    return String(path.prefix(7))
                }
                return nil
            }

            // Handle standard drive paths
            if path.count >= 2 && path.dropFirst().hasPrefix(":") {
                return String(path.prefix(3))
            }

            return nil
        }
    }
#endif

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
    /// ## Platform Implementation
    ///
    /// Requirements discovery is in platform-specific packages:
    /// - POSIX: `swift-kernel` (`Kernel.File.Direct.Requirements`)
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

// MARK: - Portable Initialization (types-only layer)

extension Kernel.File.Direct.Requirements {
    /// Creates requirements for a path.
    ///
    /// This is a placeholder that returns platform-appropriate defaults.
    /// Actual discovery is in platform-specific packages.
    public init(_ path: borrowing Path.Borrowed) {
        #if os(macOS)
            self = .unknown(reason: .platformUnsupported)
        #elseif os(Linux)
            self = .unknown(reason: .sectorSizeUndetermined)
        #elseif os(Windows)
            self = .known(Alignment(uniform: .`4096`))
        #else
            self = .unknown(reason: .platformUnsupported)
        #endif
    }
}

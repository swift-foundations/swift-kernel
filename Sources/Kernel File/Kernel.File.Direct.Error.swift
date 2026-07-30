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

public import Error_Primitives
public import Memory_Primitives

extension Kernel.File.Direct {
    /// Errors that can occur during Direct I/O operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Direct I/O is not supported on this platform or filesystem.
        ///
        /// This occurs when:
        /// - Using `.direct` mode on macOS (use `.uncached` instead)
        /// - The filesystem doesn't support `O_DIRECT` or `NO_BUFFERING`
        /// - Requirements are `.unknown` and cannot be determined
        case notSupported

        /// The buffer memory address is not properly aligned.
        ///
        /// Direct I/O requires the buffer to be aligned to the sector size.
        /// Use `Buffer.Aligned` for portable aligned allocation.
        case misalignedBuffer(address: Memory.Address, required: Memory.Alignment)

        /// The file offset is not properly aligned.
        ///
        /// Direct I/O requires file offsets to be multiples of the sector size.
        case misalignedOffset(offset: Int64, required: Memory.Alignment)

        /// The I/O length is not a valid multiple of the sector size.
        ///
        /// Direct I/O requires transfer lengths to be exact multiples.
        case invalidLength(length: Int, requiredMultiple: Memory.Alignment)

        /// Failed to enable or disable cache bypass mode.
        case modeChange

        /// The file handle is not valid or not open for the requested operation.
        case invalidHandle

        /// Platform-specific error with error code.
        case platform(code: Error_Primitives.Error.Code, operation: Operation)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.Direct.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .notSupported:
            return "Direct I/O not supported"

        case .misalignedBuffer(let address, let required):
            return "Buffer address \(address) not aligned to \(required)"

        case .misalignedOffset(let offset, let required):
            return "File offset \(offset) not aligned to \(required) bytes"

        case .invalidLength(let length, let requiredMultiple):
            return "Length \(length) is not a multiple of \(requiredMultiple)"

        case .modeChange:
            return "Failed to change cache mode"

        case .invalidHandle:
            return "Invalid file handle"

        case .platform(let code, let operation):
            return "Platform error \(code) during \(operation)"
        }
    }
}

// MARK: - Platform Bindings
//
// Per [PLAT-ARCH-008c], the platform-specific `init(from syscall:)` and
// `init(code:operation:)` mapping lives beside this type at L3:
// - POSIX: `swift-kernel` (`Kernel.File.Direct.Error+code.swift`)
// - Windows: `swift-windows-standard` (`Windows.Kernel.File.Direct.Error+code.swift`)

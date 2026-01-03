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

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

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
        case misalignedBuffer(address: Int, required: Int)

        /// The file offset is not properly aligned.
        ///
        /// Direct I/O requires file offsets to be multiples of the sector size.
        case misalignedOffset(offset: Int64, required: Int)

        /// The I/O length is not a valid multiple of the sector size.
        ///
        /// Direct I/O requires transfer lengths to be exact multiples.
        case invalidLength(length: Int, requiredMultiple: Int)

        /// Failed to enable or disable cache bypass mode.
        case modeChange

        /// The file handle is not valid or not open for the requested operation.
        case invalidHandle

        /// Platform-specific error with error code.
        case platform(code: Kernel.Error.Code, operation: Operation)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.File.Direct.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notSupported:
            return "Direct I/O not supported"
        case .misalignedBuffer(let address, let required):
            return "Buffer address 0x\(String(address, radix: 16)) not aligned to \(required) bytes"
        case .misalignedOffset(let offset, let required):
            return "File offset \(offset) not aligned to \(required) bytes"
        case .invalidLength(let length, let requiredMultiple):
            return "Length \(length) is not a multiple of \(requiredMultiple)"
        case .modeChange:
            return "Failed to change cache mode"
        case .invalidHandle:
            return "Invalid file handle"
        case .platform(let code, let operation):
            if let message = Kernel.Error.message(for: code) {
                return "Platform error during \(operation): \(message)"
            }
            return "Platform error \(code) during \(operation)"
        }
    }
}

// MARK: - Operation

extension Kernel.File.Direct.Error {
    /// Direct I/O operation types for syscall error context.
    public enum Operation: String, Sendable, Equatable {
        case open
        case setNoCache
        case clearNoCache
        case getSectorSize
        case read
        case write
    }
}

// MARK: - Syscall

extension Kernel.File.Direct.Error {
    /// Raw syscall-level error with platform-specific details.
    ///
    /// This type captures the exact errno/win32 error code from syscalls.
    /// It is translated to the semantic `Kernel.File.Direct.Error` at API boundaries.
    package enum Syscall: Swift.Error, Sendable, Equatable {
        /// Platform syscall failure.
        case platform(code: Kernel.Error.Code, operation: Operation)

        /// Invalid file descriptor provided.
        case invalidDescriptor(operation: Operation)

        /// Alignment validation failed.
        case alignmentViolation(operation: Operation)

        /// Operation not supported on this platform/filesystem.
        case notSupported(operation: Operation)
    }
}

// MARK: - Translation from Syscall

extension Kernel.File.Direct.Error {
    /// Creates a semantic error from a raw syscall error.
    package init(from syscall: Syscall) {
        switch syscall {
        case .invalidDescriptor:
            self = .invalidHandle

        case .alignmentViolation(let operation):
            // Alignment violation during the operation
            self = .platform(code: .posix(-1), operation: operation)

        case .notSupported:
            self = .notSupported

        case .platform(let code, let operation):
            self = Self.fromCode(code, operation: operation)
        }
    }

    /// Maps platform error code to semantic error.
    private static func fromCode(_ code: Kernel.Error.Code, operation: Operation) -> Self {
        switch code {
        case .posix(let errno):
            #if !os(Windows)
            switch errno {
            case EINVAL:
                // EINVAL from O_DIRECT often means alignment violation
                return .platform(code: code, operation: operation)
            case EBADF:
                return .invalidHandle
            case ENOTSUP, EOPNOTSUPP:
                return .notSupported
            case EACCES, EPERM:
                return .platform(code: code, operation: operation)
            default:
                return .platform(code: code, operation: operation)
            }
            #else
            return .platform(code: code, operation: operation)
            #endif

        case .win32(let error):
            #if os(Windows)
            switch error {
            case UInt32(ERROR_INVALID_PARAMETER):
                return .platform(code: code, operation: operation)
            case UInt32(ERROR_INVALID_HANDLE):
                return .invalidHandle
            case UInt32(ERROR_NOT_SUPPORTED):
                return .notSupported
            case UInt32(ERROR_ACCESS_DENIED):
                return .platform(code: code, operation: operation)
            default:
                return .platform(code: code, operation: operation)
            }
            #else
            return .platform(code: code, operation: operation)
            #endif
        }
    }
}

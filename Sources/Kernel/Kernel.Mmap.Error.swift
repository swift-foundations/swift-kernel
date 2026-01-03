// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel.Mmap {
    /// Errors from mmap operations.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Failed to map memory.
        case mapFailed(errno: Int32)

        /// Failed to unmap memory.
        case unmapFailed(errno: Int32)

        /// Failed to sync memory to disk.
        case syncFailed(errno: Int32)

        /// Failed to change memory protection.
        case protectFailed(errno: Int32)

        /// Invalid argument (e.g., length is 0).
        case invalidArgument(String)

        #if os(Windows)
            /// Windows-specific error.
            case windows(code: UInt32, operation: String)
        #endif
    }
}

extension Kernel.Mmap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .mapFailed(let errno):
            return "mmap failed (errno: \(errno))"
        case .unmapFailed(let errno):
            return "munmap failed (errno: \(errno))"
        case .syncFailed(let errno):
            return "msync failed (errno: \(errno))"
        case .protectFailed(let errno):
            return "mprotect failed (errno: \(errno))"
        case .invalidArgument(let msg):
            return "invalid argument: \(msg)"
        #if os(Windows)
            case .windows(let code, let operation):
                return "\(operation) failed (error: \(code))"
        #endif
        }
    }
}

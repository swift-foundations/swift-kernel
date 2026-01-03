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
        case map(Kernel.Error.Code)

        /// Failed to unmap memory.
        case unmap(Kernel.Error.Code)

        /// Failed to sync memory to disk.
        case sync(Kernel.Error.Code)

        /// Failed to change memory protection.
        case protect(Kernel.Error.Code)

        /// Invalid argument.
        case invalid(Validation)

        /// Validation failure reasons.
        public enum Validation: Sendable, Equatable, Hashable {
            /// Length must be greater than zero.
            case length
            /// Address alignment is invalid.
            case alignment
            /// Offset is invalid.
            case offset
        }
    }
}

extension Kernel.Mmap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .map(let code):
            return "mmap failed (\(code))"
        case .unmap(let code):
            return "munmap failed (\(code))"
        case .sync(let code):
            return "msync failed (\(code))"
        case .protect(let code):
            return "mprotect failed (\(code))"
        case .invalid(let validation):
            return "invalid argument: \(validation)"
        }
    }
}

extension Kernel.Mmap.Error.Validation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .length: return "length must be greater than zero"
        case .alignment: return "address alignment is invalid"
        case .offset: return "offset is invalid"
        }
    }
}

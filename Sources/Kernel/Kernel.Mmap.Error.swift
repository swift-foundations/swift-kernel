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
        case map(errno: Int32)

        /// Failed to unmap memory.
        case unmap(errno: Int32)

        /// Failed to sync memory to disk.
        case sync(errno: Int32)

        /// Failed to change memory protection.
        case protect(errno: Int32)

        /// Invalid argument.
        case invalid(Validation)

        #if os(Windows)
            /// Windows-specific error.
            case windows(code: UInt32, operation: Operation)
        #endif

        /// Validation failure reasons.
        public enum Validation: Sendable, Equatable, Hashable {
            /// Length must be greater than zero.
            case length
            /// Address alignment is invalid.
            case alignment
            /// Offset is invalid.
            case offset
        }

        #if os(Windows)
            /// Windows mmap operations.
            public enum Operation: Sendable, Equatable, Hashable {
                case createFileMapping
                case mapViewOfFile
                case unmapViewOfFile
                case flushViewOfFile
                case virtualAlloc
                case virtualFree
                case virtualProtect
            }
        #endif
    }
}

extension Kernel.Mmap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .map(let errno):
            return "mmap failed (errno: \(errno))"
        case .unmap(let errno):
            return "munmap failed (errno: \(errno))"
        case .sync(let errno):
            return "msync failed (errno: \(errno))"
        case .protect(let errno):
            return "mprotect failed (errno: \(errno))"
        case .invalid(let validation):
            return "invalid argument: \(validation)"
        #if os(Windows)
            case .windows(let code, let operation):
                return "\(operation) failed (error: \(code))"
        #endif
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

#if os(Windows)
extension Kernel.Mmap.Error.Operation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .createFileMapping: return "CreateFileMapping"
        case .mapViewOfFile: return "MapViewOfFile"
        case .unmapViewOfFile: return "UnmapViewOfFile"
        case .flushViewOfFile: return "FlushViewOfFile"
        case .virtualAlloc: return "VirtualAlloc"
        case .virtualFree: return "VirtualFree"
        case .virtualProtect: return "VirtualProtect"
        }
    }
}
#endif

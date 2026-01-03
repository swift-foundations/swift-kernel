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

#if os(Windows)
public import WinSDK
#endif

extension Kernel.Memory.Map {
    /// A mapped memory region.
    ///
    /// Represents a region of memory that has been mapped into the process
    /// address space. This type abstracts over platform differences:
    /// - On POSIX: wraps the base address and length
    /// - On Windows: also tracks the mapping handle for cleanup
    ///
    /// Use `Kernel.Memory.Map.unmap(_:)` to release the region.
    public struct Region: @unchecked Sendable {
        /// The base address of the mapped region.
        public let baseAddress: UnsafeMutableRawPointer

        /// The length of the mapped region in bytes.
        public let length: Int

        #if os(Windows)
        /// The file mapping handle (Windows only).
        ///
        /// This handle must be closed after unmapping the view.
        @usableFromInline
        internal let mappingHandle: HANDLE

        /// Creates a mapped region with the given address, length, and Windows handle.
        @inlinable
        public init(baseAddress: UnsafeMutableRawPointer, length: Int, mappingHandle: HANDLE) {
            self.baseAddress = baseAddress
            self.length = length
            self.mappingHandle = mappingHandle
        }
        #else
        /// Creates a mapped region with the given address and length.
        @inlinable
        public init(baseAddress: UnsafeMutableRawPointer, length: Int) {
            self.baseAddress = baseAddress
            self.length = length
        }
        #endif
    }
}

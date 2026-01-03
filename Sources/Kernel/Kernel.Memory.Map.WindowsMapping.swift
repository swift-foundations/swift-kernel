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

extension Kernel.Memory.Map {
    /// Result of a Windows memory mapping operation.
    ///
    /// ## Thread Safety
    ///
    /// Uses `@unchecked Sendable` because the stored pointers/handles are not
    /// `Sendable`, but this is safe because:
    /// - `baseAddress` is an opaque pointer to kernel-managed memory
    /// - `mappingHandle` is an opaque kernel identifier (never dereferenced)
    /// - Both are immutable once created
    /// - The caller is responsible for proper synchronization when accessing
    ///   the mapped memory region
    public struct WindowsMapping: @unchecked Sendable {
        /// The base address of the mapped view.
        public nonisolated(unsafe) let baseAddress: UnsafeMutableRawPointer

        /// The file mapping handle (must be closed after unmapping).
        public nonisolated(unsafe) let mappingHandle: HANDLE

        /// Creates a WindowsMapping with the given address and handle.
        @inlinable
        public init(baseAddress: UnsafeMutableRawPointer, mappingHandle: HANDLE) {
            self.baseAddress = baseAddress
            self.mappingHandle = mappingHandle
        }
    }
}

#endif

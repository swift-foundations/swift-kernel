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

extension Kernel.Memory.Map {
    /// Anonymous memory mapping operations.
    public enum Anonymous {}
}

// MARK: - POSIX Implementation

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
        import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.Memory.Map.Anonymous {
        /// Maps anonymous memory.
        ///
        /// Convenience wrapper for anonymous mappings.
        ///
        /// - Parameters:
        ///   - length: Number of bytes to map.
        ///   - protection: Memory protection flags.
        ///   - shared: If true, mapping is shared; otherwise private.
        /// - Returns: Pointer to the mapped region.
        /// - Throws: `Error.map` on failure.
        @inlinable
        public static func map(
            length: Int,
            protection: Kernel.Memory.Map.Protection = .readWrite,
            shared: Bool = false
        ) throws(Kernel.Memory.Map.Error) -> UnsafeMutableRawPointer {
            let flags: Kernel.Memory.Map.Flags =
                shared
                ? .shared | .anonymous
                : .private | .anonymous
            return try Kernel.Memory.Map.map(length: length, protection: protection, flags: flags)
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    import WinSDK

    extension Kernel.Memory.Map.Anonymous {
        /// Maps anonymous memory (pagefile-backed) on Windows.
        ///
        /// - Parameters:
        ///   - length: Number of bytes to map.
        ///   - protection: Memory protection flags.
        /// - Returns: A `WindowsMapping` containing the address and mapping handle.
        /// - Throws: `Error.windows` on failure.
        public static func map(
            length: Int,
            protection: Kernel.Memory.Map.Protection = .readWrite
        ) throws(Kernel.Memory.Map.Error) -> Kernel.Memory.Map.WindowsMapping {
            guard length > 0 else {
                throw .invalid(.length)
            }

            let pageProtection = protection.windowsPageProtection
            let maxSizeHigh = DWORD(UInt64(length) >> 32)
            let maxSizeLow = DWORD(UInt64(length) & 0xFFFF_FFFF)

            let mappingHandle = CreateFileMappingW(
                INVALID_HANDLE_VALUE,
                nil,
                pageProtection,
                maxSizeHigh,
                maxSizeLow,
                nil
            )

            guard let mappingHandle, mappingHandle != INVALID_HANDLE_VALUE else {
                throw .map(.captureLastError())
            }

            let access = protection.windowsFileMapAccess

            let viewAddress = MapViewOfFile(
                mappingHandle,
                access,
                0,
                0,
                SIZE_T(length)
            )

            guard let address = viewAddress else {
                CloseHandle(mappingHandle)
                throw .map(.captureLastError())
            }

            return Kernel.Memory.Map.WindowsMapping(baseAddress: address, mappingHandle: mappingHandle)
        }
    }

#endif

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

    extension Kernel.Mmap.Anonymous {
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
            protection: Kernel.Mmap.Protection = .readWrite,
            shared: Bool = false
        ) throws(Kernel.Mmap.Error) -> UnsafeMutableRawPointer {
            let flags: Kernel.Mmap.Flags =
                shared
                ? .shared | .anonymous
                : .private | .anonymous
            return try Kernel.Mmap.map(length: length, protection: protection, flags: flags)
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    import WinSDK

    extension Kernel.Mmap.Anonymous {
        /// Maps anonymous memory (pagefile-backed) on Windows.
        ///
        /// - Parameters:
        ///   - length: Number of bytes to map.
        ///   - protection: Memory protection flags.
        /// - Returns: A `WindowsMapping` containing the address and mapping handle.
        /// - Throws: `Error.windows` on failure.
        public static func map(
            length: Int,
            protection: Kernel.Mmap.Protection = .readWrite
        ) throws(Kernel.Mmap.Error) -> Kernel.Mmap.WindowsMapping {
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

            return Kernel.Mmap.WindowsMapping(baseAddress: address, mappingHandle: mappingHandle)
        }
    }

#endif

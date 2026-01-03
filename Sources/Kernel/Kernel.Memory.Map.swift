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

extension Kernel.Memory {
    /// Raw memory mapping syscall wrappers.
    ///
    /// Memory mapping allows files and anonymous memory to be mapped
    /// directly into the process address space for efficient I/O.
    ///
    /// This namespace provides policy-free syscall wrappers.
    /// Higher layers (swift-mmap, swift-io) build region management,
    /// lock coordination, and RAII semantics on top of these primitives.
    public enum Map {}
}

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Memory.Map {
        /// Maps memory into the process address space.
        ///
        /// - Parameters:
        ///   - addr: Suggested address, or `nil` for kernel to choose.
        ///   - length: Number of bytes to map (must be > 0).
        ///   - protection: Memory protection flags.
        ///   - flags: Mapping flags.
        ///   - fd: File descriptor to map, or -1 for anonymous.
        ///   - offset: Offset into the file (must be page-aligned).
        /// - Returns: Pointer to the mapped region.
        /// - Throws: `Error.map` on failure.
        @inlinable
        public static func map(
            addr: UnsafeMutableRawPointer? = nil,
            length: Int,
            protection: Protection,
            flags: Flags,
            fd: Kernel.Descriptor = .invalid,
            offset: Int64 = 0
        ) throws(Error) -> UnsafeMutableRawPointer {
            guard length > 0 else {
                throw .invalid(.length)
            }

            let result = mmap(
                addr,
                length,
                protection.rawValue,
                flags.rawValue,
                fd.rawValue,
                off_t(offset)
            )

            guard result != MAP_FAILED else {
                throw .map(.captureErrno())
            }

            return result!
        }

        /// Unmaps a previously mapped region.
        ///
        /// - Parameters:
        ///   - addr: The base address of the mapping.
        ///   - length: The length of the mapping.
        /// - Throws: `Error.unmap` on failure.
        @inlinable
        public static func unmap(
            addr: UnsafeMutableRawPointer,
            length: Int
        ) throws(Error) {
            let result = munmap(addr, length)
            guard result == 0 else {
                throw .unmap(.captureErrno())
            }
        }

        /// Synchronizes a mapped region to disk.
        ///
        /// - Parameters:
        ///   - addr: The base address of the region.
        ///   - length: The length of the region.
        ///   - flags: Sync flags (sync, async, invalidate).
        /// - Throws: `Error.sync` on failure.
        @inlinable
        public static func sync(
            addr: UnsafeMutableRawPointer,
            length: Int,
            flags: Sync.Flags = .sync
        ) throws(Error) {
            let result = msync(addr, length, flags.rawValue)
            guard result == 0 else {
                throw .sync(.captureErrno())
            }
        }

        /// Changes the protection on a mapped region.
        ///
        /// - Parameters:
        ///   - addr: The base address (must be page-aligned).
        ///   - length: The length of the region.
        ///   - protection: The new protection flags.
        /// - Throws: `Error.protect` on failure.
        @inlinable
        public static func protect(
            addr: UnsafeMutableRawPointer,
            length: Int,
            protection: Protection
        ) throws(Error) {
            let result = mprotect(addr, length, protection.rawValue)
            guard result == 0 else {
                throw .protect(.captureErrno())
            }
        }

        /// Advises the kernel about expected access patterns.
        ///
        /// This is advisory only; errors are ignored.
        ///
        /// - Parameters:
        ///   - addr: The base address.
        ///   - length: The length of the region.
        ///   - advice: The advice type.
        @inlinable
        public static func advise(
            addr: UnsafeMutableRawPointer,
            length: Int,
            advice: Advice
        ) {
            _ = madvise(addr, length, advice.rawValue)
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.Memory.Map {
        /// Unmaps a view and closes the mapping handle on Windows.
        ///
        /// - Parameter mapping: The mapping to unmap.
        /// - Throws: `Error.unmap` on failure.
        public static func unmap(_ mapping: WindowsMapping) throws(Error) {
            let unmapResult = UnmapViewOfFile(mapping.baseAddress)
            CloseHandle(mapping.mappingHandle)

            guard unmapResult else {
                throw .unmap(.captureLastError())
            }
        }

        /// Flushes a mapped view to disk on Windows.
        ///
        /// - Parameters:
        ///   - addr: The base address.
        ///   - length: The length of the region.
        /// - Throws: `Error.sync` on failure.
        public static func sync(
            addr: UnsafeMutableRawPointer,
            length: Int
        ) throws(Error) {
            let result = FlushViewOfFile(addr, SIZE_T(length))
            guard result else {
                throw .sync(.captureLastError())
            }
        }

        /// Changes memory protection on Windows.
        ///
        /// - Parameters:
        ///   - addr: The base address.
        ///   - length: The length of the region.
        ///   - protection: The new protection flags.
        /// - Throws: `Error.protect` on failure.
        public static func protect(
            addr: UnsafeMutableRawPointer,
            length: Int,
            protection: Protection
        ) throws(Error) {
            var oldProtection: DWORD = 0
            let result = VirtualProtect(
                addr,
                SIZE_T(length),
                protection.windowsPageProtection,
                &oldProtection
            )
            guard result else {
                throw .protect(.captureLastError())
            }
        }

        /// Advises the system about access patterns on Windows.
        ///
        /// Windows has limited madvise-equivalent functionality.
        /// This is currently a no-op.
        public static func advise(
            addr: UnsafeMutableRawPointer,
            length: Int,
            advice: Advice
        ) {
            // Windows doesn't have direct madvise equivalent
            // PrefetchVirtualMemory requires Windows 8+ and complex setup
        }
    }

#endif

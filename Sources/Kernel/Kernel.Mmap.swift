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

extension Kernel {
    /// Raw memory mapping syscall wrappers.
    ///
    /// Memory mapping allows files and anonymous memory to be mapped
    /// directly into the process address space for efficient I/O.
    ///
    /// This namespace provides policy-free syscall wrappers.
    /// Higher layers (swift-mmap, swift-io) build region management,
    /// lock coordination, and RAII semantics on top of these primitives.
    public enum Mmap {}
}

// MARK: - Error Type

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

// MARK: - Protection Flags

extension Kernel.Mmap {
    /// Memory protection flags.
    ///
    /// This is a custom value type (not OptionSet) to stay faithful
    /// to the OS model and avoid policy creep.
    public struct Protection: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// No access permitted.
        public static let none = Protection(rawValue: 0)

        /// Combines multiple protection flags.
        @inlinable
        public static func | (lhs: Protection, rhs: Protection) -> Protection {
            Protection(rawValue: lhs.rawValue | rhs.rawValue)
        }

        /// Checks if this contains another protection flag.
        @inlinable
        public func contains(_ other: Protection) -> Bool {
            (rawValue & other.rawValue) == other.rawValue
        }
    }
}

// MARK: - Mapping Flags

extension Kernel.Mmap {
    /// Flags controlling mapping behavior.
    public struct Flags: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Combines multiple flags.
        @inlinable
        public static func | (lhs: Flags, rhs: Flags) -> Flags {
            Flags(rawValue: lhs.rawValue | rhs.rawValue)
        }
    }
}

// MARK: - Sync Flags

extension Kernel.Mmap {
    /// Flags for msync operation.
    public struct SyncFlags: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Combines multiple flags.
        @inlinable
        public static func | (lhs: SyncFlags, rhs: SyncFlags) -> SyncFlags {
            SyncFlags(rawValue: lhs.rawValue | rhs.rawValue)
        }
    }
}

// MARK: - Advice

extension Kernel.Mmap {
    /// Memory access advice for madvise.
    public struct Advice: Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - POSIX Implementation

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    // MARK: Platform Constants

    extension Kernel.Mmap.Protection {
        /// Pages may be read.
        public static let read = Self(rawValue: PROT_READ)

        /// Pages may be written.
        public static let write = Self(rawValue: PROT_WRITE)

        /// Pages may be executed.
        public static let execute = Self(rawValue: PROT_EXEC)

        /// Read and write access.
        public static let readWrite = read | write
    }

    extension Kernel.Mmap.Flags {
        /// Changes are shared with other processes.
        public static let shared = Self(rawValue: MAP_SHARED)

        /// Changes are private (copy-on-write).
        public static let `private` = Self(rawValue: MAP_PRIVATE)

        /// Anonymous mapping (not backed by a file).
        public static let anonymous = Self(rawValue: MAP_ANON)

        /// Mapping must be at the specified address (hint becomes requirement).
        public static let fixed = Self(rawValue: MAP_FIXED)
    }

    extension Kernel.Mmap.SyncFlags {
        /// Perform synchronous writes.
        public static let sync = Self(rawValue: MS_SYNC)

        /// Schedule writes but return immediately.
        public static let async = Self(rawValue: MS_ASYNC)

        /// Invalidate cached data.
        public static let invalidate = Self(rawValue: MS_INVALIDATE)
    }

    extension Kernel.Mmap.Advice {
        /// Normal access pattern.
        public static let normal = Self(rawValue: MADV_NORMAL)

        /// Sequential access expected.
        public static let sequential = Self(rawValue: MADV_SEQUENTIAL)

        /// Random access expected.
        public static let random = Self(rawValue: MADV_RANDOM)

        /// Will need this data soon.
        public static let willNeed = Self(rawValue: MADV_WILLNEED)

        /// Will not need this data soon.
        public static let dontNeed = Self(rawValue: MADV_DONTNEED)
    }

    // MARK: Syscalls

    extension Kernel.Mmap {
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
        /// - Throws: `Error.mapFailed` on failure.
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
                throw .invalidArgument("length must be > 0")
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
                throw .mapFailed(errno: errno)
            }

            return result!
        }

        /// Maps anonymous memory.
        ///
        /// Convenience wrapper for anonymous mappings.
        ///
        /// - Parameters:
        ///   - length: Number of bytes to map.
        ///   - protection: Memory protection flags.
        ///   - shared: If true, mapping is shared; otherwise private.
        /// - Returns: Pointer to the mapped region.
        /// - Throws: `Error.mapFailed` on failure.
        @inlinable
        public static func mapAnonymous(
            length: Int,
            protection: Protection = .readWrite,
            shared: Bool = false
        ) throws(Error) -> UnsafeMutableRawPointer {
            let flags: Flags =
                shared
                ? .shared | .anonymous
                : .private | .anonymous
            return try map(length: length, protection: protection, flags: flags)
        }

        /// Unmaps a previously mapped region.
        ///
        /// - Parameters:
        ///   - addr: The base address of the mapping.
        ///   - length: The length of the mapping.
        /// - Throws: `Error.unmapFailed` on failure.
        @inlinable
        public static func unmap(
            addr: UnsafeMutableRawPointer,
            length: Int
        ) throws(Error) {
            let result = munmap(addr, length)
            guard result == 0 else {
                throw .unmapFailed(errno: errno)
            }
        }

        /// Synchronizes a mapped region to disk.
        ///
        /// - Parameters:
        ///   - addr: The base address of the region.
        ///   - length: The length of the region.
        ///   - flags: Sync flags (sync, async, invalidate).
        /// - Throws: `Error.syncFailed` on failure.
        @inlinable
        public static func sync(
            addr: UnsafeMutableRawPointer,
            length: Int,
            flags: SyncFlags = .sync
        ) throws(Error) {
            let result = msync(addr, length, flags.rawValue)
            guard result == 0 else {
                throw .syncFailed(errno: errno)
            }
        }

        /// Changes the protection on a mapped region.
        ///
        /// - Parameters:
        ///   - addr: The base address (must be page-aligned).
        ///   - length: The length of the region.
        ///   - protection: The new protection flags.
        /// - Throws: `Error.protectFailed` on failure.
        @inlinable
        public static func protect(
            addr: UnsafeMutableRawPointer,
            length: Int,
            protection: Protection
        ) throws(Error) {
            let result = mprotect(addr, length, protection.rawValue)
            guard result == 0 else {
                throw .protectFailed(errno: errno)
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

    extension Kernel.Mmap.Protection {
        /// Pages may be read.
        public static let read = Self(rawValue: 1)

        /// Pages may be written.
        public static let write = Self(rawValue: 2)

        /// Pages may be executed.
        public static let execute = Self(rawValue: 4)

        /// Read and write access.
        public static let readWrite = read | write

        /// Converts to Windows page protection constant.
        var windowsPageProtection: DWORD {
            let r = contains(.read)
            let w = contains(.write)
            let x = contains(.execute)

            switch (r, w, x) {
            case (false, false, false): return DWORD(PAGE_NOACCESS)
            case (true, false, false): return DWORD(PAGE_READONLY)
            case (true, true, false): return DWORD(PAGE_READWRITE)
            case (true, false, true): return DWORD(PAGE_EXECUTE_READ)
            case (true, true, true): return DWORD(PAGE_EXECUTE_READWRITE)
            case (false, false, true): return DWORD(PAGE_EXECUTE)
            case (false, true, false): return DWORD(PAGE_READWRITE)
            case (false, true, true): return DWORD(PAGE_EXECUTE_READWRITE)
            }
        }

        /// Converts to Windows file map access flags.
        var windowsFileMapAccess: DWORD {
            var access: DWORD = 0
            if contains(.read) { access |= DWORD(FILE_MAP_READ) }
            if contains(.write) { access |= DWORD(FILE_MAP_WRITE) }
            if contains(.execute) { access |= DWORD(FILE_MAP_EXECUTE) }
            return access
        }
    }

    extension Kernel.Mmap.Flags {
        /// Changes are shared.
        public static let shared = Self(rawValue: 1)

        /// Changes are private (copy-on-write).
        public static let `private` = Self(rawValue: 2)

        /// Anonymous mapping.
        public static let anonymous = Self(rawValue: 4)

        /// Fixed address.
        public static let fixed = Self(rawValue: 8)
    }

    extension Kernel.Mmap.SyncFlags {
        public static let sync = Self(rawValue: 1)
        public static let async = Self(rawValue: 2)
        public static let invalidate = Self(rawValue: 4)
    }

    extension Kernel.Mmap.Advice {
        public static let normal = Self(rawValue: 0)
        public static let sequential = Self(rawValue: 1)
        public static let random = Self(rawValue: 2)
        public static let willNeed = Self(rawValue: 3)
        public static let dontNeed = Self(rawValue: 4)
    }

    extension Kernel.Mmap {
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
        }

        /// Maps a file into memory using Windows APIs.
        ///
        /// - Parameters:
        ///   - fileHandle: The file handle to map.
        ///   - offset: Offset into the file.
        ///   - length: Number of bytes to map.
        ///   - protection: Memory protection flags.
        ///   - copyOnWrite: If true, use copy-on-write semantics.
        /// - Returns: A `WindowsMapping` containing the address and mapping handle.
        /// - Throws: `Error.windows` on failure.
        public static func mapFile(
            handle fileHandle: HANDLE,
            offset: Int64,
            length: Int,
            protection: Protection,
            copyOnWrite: Bool = false
        ) throws(Error) -> WindowsMapping {
            guard length > 0 else {
                throw .invalidArgument("length must be > 0")
            }

            guard fileHandle != INVALID_HANDLE_VALUE else {
                throw .invalidArgument("invalid file handle")
            }

            var pageProtection = protection.windowsPageProtection
            if copyOnWrite {
                if pageProtection == DWORD(PAGE_READWRITE) {
                    pageProtection = DWORD(PAGE_WRITECOPY)
                } else if pageProtection == DWORD(PAGE_EXECUTE_READWRITE) {
                    pageProtection = DWORD(PAGE_EXECUTE_WRITECOPY)
                }
            }

            let maxSize = UInt64(offset) + UInt64(length)
            let maxSizeHigh = DWORD(maxSize >> 32)
            let maxSizeLow = DWORD(maxSize & 0xFFFF_FFFF)

            let mappingHandle = CreateFileMappingW(
                fileHandle,
                nil,
                pageProtection,
                maxSizeHigh,
                maxSizeLow,
                nil
            )

            guard let mappingHandle, mappingHandle != INVALID_HANDLE_VALUE else {
                throw .windows(code: GetLastError(), operation: "CreateFileMapping")
            }

            var access = protection.windowsFileMapAccess
            if copyOnWrite {
                access = DWORD(FILE_MAP_COPY)
            }

            let offsetHigh = DWORD(UInt64(offset) >> 32)
            let offsetLow = DWORD(UInt64(offset) & 0xFFFF_FFFF)

            let viewAddress = MapViewOfFile(
                mappingHandle,
                access,
                offsetHigh,
                offsetLow,
                SIZE_T(length)
            )

            guard let address = viewAddress else {
                CloseHandle(mappingHandle)
                throw .windows(code: GetLastError(), operation: "MapViewOfFile")
            }

            return WindowsMapping(baseAddress: address, mappingHandle: mappingHandle)
        }

        /// Maps anonymous memory (pagefile-backed) on Windows.
        ///
        /// - Parameters:
        ///   - length: Number of bytes to map.
        ///   - protection: Memory protection flags.
        /// - Returns: A `WindowsMapping` containing the address and mapping handle.
        /// - Throws: `Error.windows` on failure.
        public static func mapAnonymous(
            length: Int,
            protection: Protection = .readWrite
        ) throws(Error) -> WindowsMapping {
            guard length > 0 else {
                throw .invalidArgument("length must be > 0")
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
                throw .windows(code: GetLastError(), operation: "CreateFileMapping")
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
                throw .windows(code: GetLastError(), operation: "MapViewOfFile")
            }

            return WindowsMapping(baseAddress: address, mappingHandle: mappingHandle)
        }

        /// Unmaps a view and closes the mapping handle on Windows.
        ///
        /// - Parameter mapping: The mapping to unmap.
        /// - Throws: `Error.windows` on failure.
        public static func unmap(_ mapping: WindowsMapping) throws(Error) {
            let unmapResult = UnmapViewOfFile(mapping.baseAddress)
            CloseHandle(mapping.mappingHandle)

            guard unmapResult else {
                throw .windows(code: GetLastError(), operation: "UnmapViewOfFile")
            }
        }

        /// Flushes a mapped view to disk on Windows.
        ///
        /// - Parameters:
        ///   - addr: The base address.
        ///   - length: The length of the region.
        /// - Throws: `Error.windows` on failure.
        public static func sync(
            addr: UnsafeMutableRawPointer,
            length: Int
        ) throws(Error) {
            let result = FlushViewOfFile(addr, SIZE_T(length))
            guard result else {
                throw .windows(code: GetLastError(), operation: "FlushViewOfFile")
            }
        }

        /// Changes memory protection on Windows.
        ///
        /// - Parameters:
        ///   - addr: The base address.
        ///   - length: The length of the region.
        ///   - protection: The new protection flags.
        /// - Throws: `Error.windows` on failure.
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
                throw .windows(code: GetLastError(), operation: "VirtualProtect")
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

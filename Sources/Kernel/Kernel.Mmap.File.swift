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
    /// File memory mapping operations.
    public enum File {}
}

// MARK: - Windows Implementation

#if os(Windows)
    import WinSDK

    extension Kernel.Mmap.File {
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
        public static func map(
            handle fileHandle: HANDLE,
            offset: Int64,
            length: Int,
            protection: Kernel.Mmap.Protection,
            copyOnWrite: Bool = false
        ) throws(Kernel.Mmap.Error) -> Kernel.Mmap.WindowsMapping {
            guard length > 0 else {
                throw .invalid(.length)
            }

            guard fileHandle != INVALID_HANDLE_VALUE else {
                throw .map(.win32(UInt32(ERROR_INVALID_HANDLE)))
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
                throw .map(.captureLastError())
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
                throw .map(.captureLastError())
            }

            return Kernel.Mmap.WindowsMapping(baseAddress: address, mappingHandle: mappingHandle)
        }
    }

#endif

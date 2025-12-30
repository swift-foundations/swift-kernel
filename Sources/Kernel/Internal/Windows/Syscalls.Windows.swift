//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

#if os(Windows)
public import SystemPackage
public import WinSDK

// MARK: - File Operations (FilePath overloads - recommended)

extension Kernel.Syscalls {
    /// Opens a file at the specified path.
    ///
    /// This is the recommended, safe overload using `FilePath` from swift-system.
    public static func open(
        path: FilePath,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        try path.withPlatformString { wpath in
            try open(
                unsafePath: wpath,
                mode: mode,
                options: options,
                permissions: permissions
            )
        }
    }

    /// Gets file metadata for a path.
    public static func stat(
        path: FilePath,
        followSymlinks: Bool
    ) throws(Kernel.Error) -> Kernel.Stat {
        try path.withPlatformString { wpath in
            try stat(unsafePath: wpath, followSymlinks: followSymlinks)
        }
    }

    /// Gets filesystem statistics for a path.
    public static func statfs(
        path: FilePath
    ) throws(Kernel.Error) -> Kernel.Statfs {
        try path.withPlatformString { wpath in
            try statfs(unsafePath: wpath)
        }
    }
}

// MARK: - File Operations (Kernel.Path overloads)

extension Kernel.Syscalls {
    /// Opens a file at the specified path.
    @inlinable
    public static func open(
        path: borrowing Kernel.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        // Convert CChar path to wide string
        let widePath = String(cString: path.cString)
        return try widePath.withCString(encodedAs: UTF16.self) { wpath in
            try open(
                unsafePath: wpath,
                mode: mode,
                options: options,
                permissions: permissions
            )
        }
    }

    /// Gets file metadata for a path.
    @inlinable
    public static func stat(
        path: borrowing Kernel.Path,
        followSymlinks: Bool
    ) throws(Kernel.Error) -> Kernel.Stat {
        let widePath = String(cString: path.cString)
        return try widePath.withCString(encodedAs: UTF16.self) { wpath in
            try stat(unsafePath: wpath, followSymlinks: followSymlinks)
        }
    }
}

// MARK: - File Operations (unsafe pointer overloads)

extension Kernel.Syscalls {
    /// Opens a file at the specified path (Windows wide string).
    @inlinable
    public static func open(
        unsafePath: UnsafePointer<WCHAR>,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options,
        permissions: UInt16
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        let desiredAccess = mode.windowsDesiredAccess
        let creationDisposition = options.windowsCreationDisposition
        let flagsAndAttributes = options.windowsFlagsAndAttributes
        let shareMode = Kernel.File.Open.Options.windowsShareMode

        let handle = CreateFileW(
            unsafePath,
            desiredAccess,
            shareMode,
            nil,  // Security attributes
            creationDisposition,
            flagsAndAttributes,
            nil   // Template file
        )

        guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
            throw Kernel.Error.currentWindowsError()
        }

        return handle
    }

    /// Closes a file handle.
    @inlinable
    public static func close(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }
        if CloseHandle(descriptor) == false {
            throw Kernel.Error.currentWindowsError()
        }
    }

    /// Reads bytes from a file handle.
    @inlinable
    public static func read(
        _ descriptor: Kernel.Descriptor,
        into buffer: UnsafeMutableRawBufferPointer
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        var bytesRead: DWORD = 0
        let result = ReadFile(
            descriptor,
            baseAddress,
            DWORD(min(buffer.count, Int(DWORD.max))),
            &bytesRead,
            nil
        )

        guard result != 0 else {
            let error = GetLastError()
            // ERROR_HANDLE_EOF is not an error, just EOF
            if error == DWORD(ERROR_HANDLE_EOF) {
                return 0
            }
            throw Kernel.Error.windows(error)
        }
        return Int(bytesRead)
    }

    /// Writes bytes to a file handle.
    @inlinable
    public static func write(
        _ descriptor: Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        var bytesWritten: DWORD = 0
        let result = WriteFile(
            descriptor,
            baseAddress,
            DWORD(min(buffer.count, Int(DWORD.max))),
            &bytesWritten,
            nil
        )

        guard result != 0 else {
            throw Kernel.Error.currentWindowsError()
        }
        return Int(bytesWritten)
    }

    /// Reads bytes from a file at a specific offset.
    @inlinable
    public static func pread(
        _ descriptor: Kernel.Descriptor,
        into buffer: UnsafeMutableRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        var overlapped = OVERLAPPED()
        overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
        overlapped.OffsetHigh = DWORD(offset >> 32)

        var bytesRead: DWORD = 0
        let result = ReadFile(
            descriptor,
            baseAddress,
            DWORD(min(buffer.count, Int(DWORD.max))),
            &bytesRead,
            &overlapped
        )

        guard result != 0 else {
            let error = GetLastError()
            if error == DWORD(ERROR_HANDLE_EOF) {
                return 0
            }
            throw Kernel.Error.windows(error)
        }
        return Int(bytesRead)
    }

    /// Writes bytes to a file at a specific offset.
    @inlinable
    public static func pwrite(
        _ descriptor: Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.Error) -> Int {
        guard let baseAddress = buffer.baseAddress else {
            return 0
        }
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        var overlapped = OVERLAPPED()
        overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
        overlapped.OffsetHigh = DWORD(offset >> 32)

        var bytesWritten: DWORD = 0
        let result = WriteFile(
            descriptor,
            baseAddress,
            DWORD(min(buffer.count, Int(DWORD.max))),
            &bytesWritten,
            &overlapped
        )

        guard result != 0 else {
            throw Kernel.Error.currentWindowsError()
        }
        return Int(bytesWritten)
    }

    /// Changes the file offset.
    @inlinable
    public static func seek(
        _ descriptor: Kernel.Descriptor,
        offset: Int64,
        origin: Kernel.Seek.Origin
    ) throws(Kernel.Error) -> Int64 {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        let moveMethod: DWORD
        switch origin {
        case .start:
            moveMethod = DWORD(FILE_BEGIN)
        case .current:
            moveMethod = DWORD(FILE_CURRENT)
        case .end:
            moveMethod = DWORD(FILE_END)
        }

        var distance = LARGE_INTEGER()
        distance.QuadPart = offset

        var newPosition = LARGE_INTEGER()
        let result = SetFilePointerEx(
            descriptor,
            distance,
            &newPosition,
            moveMethod
        )

        guard result != 0 else {
            throw Kernel.Error.currentWindowsError()
        }
        return newPosition.QuadPart
    }

    /// Synchronizes file data to disk.
    @inlinable
    public static func sync(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }
        if FlushFileBuffers(descriptor) == false {
            throw Kernel.Error.currentWindowsError()
        }
    }

    /// Truncates a file to a specified length.
    @inlinable
    public static func truncate(
        _ descriptor: Kernel.Descriptor,
        to length: Int64
    ) throws(Kernel.Error) {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        // Save current position
        var currentPos = LARGE_INTEGER()
        var zero = LARGE_INTEGER()
        zero.QuadPart = 0
        guard SetFilePointerEx(descriptor, zero, &currentPos, DWORD(FILE_CURRENT)) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Seek to new end
        var newEnd = LARGE_INTEGER()
        newEnd.QuadPart = length
        guard SetFilePointerEx(descriptor, newEnd, nil, DWORD(FILE_BEGIN)) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Set end of file
        guard SetEndOfFile(descriptor) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Restore position (if within new bounds)
        if currentPos.QuadPart <= length {
            _ = SetFilePointerEx(descriptor, currentPos, nil, DWORD(FILE_BEGIN))
        }
    }

    /// Duplicates a file handle.
    @inlinable
    public static func duplicate(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) -> Kernel.Descriptor {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        var newHandle: HANDLE? = nil
        let currentProcess = GetCurrentProcess()

        let result = DuplicateHandle(
            currentProcess,
            descriptor,
            currentProcess,
            &newHandle,
            0,
            false,
            DWORD(DUPLICATE_SAME_ACCESS)
        )

        guard result != 0, let handle = newHandle, handle != INVALID_HANDLE_VALUE else {
            throw Kernel.Error.currentWindowsError()
        }
        return handle
    }
}

// MARK: - Stat Operations

extension Kernel.Syscalls {
    /// Gets file metadata for a path.
    @inlinable
    public static func stat(
        unsafePath: UnsafePointer<WCHAR>,
        followSymlinks: Bool
    ) throws(Kernel.Error) -> Kernel.Stat {
        // Use CreateFileW to open for metadata, then GetFileInformationByHandle
        var flags = DWORD(FILE_FLAG_BACKUP_SEMANTICS)
        if !followSymlinks {
            flags |= DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        }

        let handle = CreateFileW(
            unsafePath,
            DWORD(FILE_READ_ATTRIBUTES),
            DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
            nil,
            DWORD(OPEN_EXISTING),
            flags,
            nil
        )

        guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
            throw Kernel.Error.currentWindowsError()
        }
        defer { CloseHandle(handle) }

        return try fstat(handle)
    }

    /// Gets file metadata for an open handle.
    @inlinable
    public static func fstat(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) -> Kernel.Stat {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        var info = BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(descriptor, &info) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        return Kernel.Stat(windows: info)
    }
}

// MARK: - Lock Operations

extension Kernel.Syscalls {
    /// Acquires a lock on a byte range.
    @inlinable
    public static func lock(
        _ descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range,
        exclusive: Bool,
        wait: Bool
    ) throws(Kernel.Error) -> Bool {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        let (start, lengthLow, lengthHigh) = lockParameters(range)
        var overlapped = OVERLAPPED()
        overlapped.Offset = DWORD(start & 0xFFFFFFFF)
        overlapped.OffsetHigh = DWORD(start >> 32)

        var flags: DWORD = 0
        if exclusive {
            flags |= DWORD(LOCKFILE_EXCLUSIVE_LOCK)
        }
        if !wait {
            flags |= DWORD(LOCKFILE_FAIL_IMMEDIATELY)
        }

        let result = LockFileEx(
            descriptor,
            flags,
            0,
            lengthLow,
            lengthHigh,
            &overlapped
        )

        if result == 0 {
            let error = GetLastError()
            // Lock contention when not waiting
            if !wait && (error == DWORD(ERROR_LOCK_VIOLATION) || error == DWORD(ERROR_LOCK_FAILED)) {
                return false
            }
            throw Kernel.Error.windows(error)
        }
        return true
    }

    /// Releases a lock on a byte range.
    @inlinable
    public static func unlock(
        _ descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range
    ) throws(Kernel.Error) {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        let (start, lengthLow, lengthHigh) = lockParameters(range)
        var overlapped = OVERLAPPED()
        overlapped.Offset = DWORD(start & 0xFFFFFFFF)
        overlapped.OffsetHigh = DWORD(start >> 32)

        let result = UnlockFileEx(
            descriptor,
            0,
            lengthLow,
            lengthHigh,
            &overlapped
        )

        guard result != 0 else {
            throw Kernel.Error.currentWindowsError()
        }
    }

    /// Computes lock parameters from range.
    @usableFromInline
    internal static func lockParameters(
        _ range: Kernel.Lock.Range
    ) -> (start: UInt64, lengthLow: DWORD, lengthHigh: DWORD) {
        switch range {
        case .file:
            // Lock from offset 0 with max length
            return (0, DWORD.max, DWORD.max)
        case .bytes(let start, let length):
            return (start, DWORD(length & 0xFFFFFFFF), DWORD(length >> 32))
        }
    }
}

// MARK: - Filesystem Statistics

extension Kernel.Syscalls {
    /// Gets filesystem statistics for a path.
    @inlinable
    public static func statfs(
        unsafePath: UnsafePointer<WCHAR>
    ) throws(Kernel.Error) -> Kernel.Statfs {
        // Get volume root from path
        var volumePath = [WCHAR](repeating: 0, count: Int(MAX_PATH) + 1)
        guard GetVolumePathNameW(unsafePath, &volumePath, DWORD(volumePath.count)) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Get disk space info
        var freeBytesAvailable: ULONGLONG = 0
        var totalBytes: ULONGLONG = 0
        var totalFreeBytes: ULONGLONG = 0

        guard GetDiskFreeSpaceExW(
            volumePath,
            &freeBytesAvailable,
            &totalBytes,
            &totalFreeBytes
        ) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Get volume info
        var volumeSerialNumber: DWORD = 0
        var maxComponentLength: DWORD = 0
        var fileSystemFlags: DWORD = 0

        _ = GetVolumeInformationW(
            volumePath,
            nil,
            0,
            &volumeSerialNumber,
            &maxComponentLength,
            &fileSystemFlags,
            nil,
            0
        )

        // Get sector size for block size
        var sectorsPerCluster: DWORD = 0
        var bytesPerSector: DWORD = 0
        var numberOfFreeClusters: DWORD = 0
        var totalNumberOfClusters: DWORD = 0

        _ = GetDiskFreeSpaceW(
            volumePath,
            &sectorsPerCluster,
            &bytesPerSector,
            &numberOfFreeClusters,
            &totalNumberOfClusters
        )

        let blockSize = UInt64(sectorsPerCluster) * UInt64(bytesPerSector)
        let blocks = blockSize > 0 ? totalBytes / blockSize : 0
        let freeBlocks = blockSize > 0 ? totalFreeBytes / blockSize : 0
        let availableBlocks = blockSize > 0 ? freeBytesAvailable / blockSize : 0

        return Kernel.Statfs(
            type: UInt64(volumeSerialNumber),
            blockSize: max(blockSize, 4096),  // Default to 4096 if unknown
            blocks: blocks,
            freeBlocks: freeBlocks,
            availableBlocks: availableBlocks,
            files: 0,  // Windows doesn't expose inode count
            freeFiles: 0,
            fsid: UInt64(volumeSerialNumber),
            nameMax: UInt64(maxComponentLength)
        )
    }

    /// Gets filesystem statistics for an open handle.
    @inlinable
    public static func fstatfs(
        _ descriptor: Kernel.Descriptor
    ) throws(Kernel.Error) -> Kernel.Statfs {
        guard descriptor != INVALID_HANDLE_VALUE else {
            throw .descriptor(.invalid)
        }

        // Get file path from handle, then call statfs
        var fileNameInfo = FILE_NAME_INFO()
        var buffer = [UInt8](repeating: 0, count: MemoryLayout<FILE_NAME_INFO>.size + Int(MAX_PATH) * 2)

        let success = buffer.withUnsafeMutableBytes { ptr in
            GetFileInformationByHandleEx(
                descriptor,
                FileNameInfo,
                ptr.baseAddress,
                DWORD(ptr.count)
            )
        }

        guard success != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Extract path and get statfs
        let info = buffer.withUnsafeBytes { ptr in
            ptr.load(as: FILE_NAME_INFO.self)
        }

        // For simplicity, get volume info directly from handle using volume serial
        var volumeInfo = BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(descriptor, &volumeInfo) != 0 else {
            throw Kernel.Error.currentWindowsError()
        }

        // Build minimal statfs from what we can get from handle
        return Kernel.Statfs(
            type: UInt64(volumeInfo.dwVolumeSerialNumber),
            blockSize: 4096,  // Default
            blocks: 0,
            freeBlocks: 0,
            availableBlocks: 0,
            files: 0,
            freeFiles: 0,
            fsid: UInt64(volumeInfo.dwVolumeSerialNumber),
            nameMax: 255
        )
    }
}

// MARK: - Stat Conversion

extension Kernel.Stat {
    /// Creates a Stat from Windows BY_HANDLE_FILE_INFORMATION.
    @inlinable
    init(windows info: BY_HANDLE_FILE_INFORMATION) {
        self.size = Int64(info.nFileSizeHigh) << 32 | Int64(info.nFileSizeLow)

        // Determine file type
        if (info.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
            self.type = .directory
        } else if (info.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
            self.type = .link(.symbolic)
        } else {
            self.type = .regular
        }

        // Windows doesn't have POSIX permissions, default to 644
        self.permissions = 0o644
        self.uid = 0
        self.gid = 0

        // File identity
        self.inode = UInt64(info.nFileIndexHigh) << 32 | UInt64(info.nFileIndexLow)
        self.device = UInt64(info.dwVolumeSerialNumber)
        self.linkCount = UInt32(info.nNumberOfLinks)

        // Timestamps
        self.accessTime = Kernel.Time(windows: info.ftLastAccessTime)
        self.modificationTime = Kernel.Time(windows: info.ftLastWriteTime)
        self.changeTime = Kernel.Time(windows: info.ftCreationTime)
    }
}

extension Kernel.Time {
    /// Creates a Time from Windows FILETIME.
    ///
    /// FILETIME is 100-nanosecond intervals since January 1, 1601.
    @inlinable
    init(windows ft: FILETIME) {
        let intervals = Int64(ft.dwHighDateTime) << 32 | Int64(ft.dwLowDateTime)
        // Difference between 1601 and 1970 in 100ns intervals
        let unixIntervals = intervals - 116_444_736_000_000_000
        let seconds = unixIntervals / 10_000_000
        let nanoseconds = (unixIntervals % 10_000_000) * 100
        self.seconds = seconds
        self.nanoseconds = Int32(nanoseconds)
    }
}

#endif

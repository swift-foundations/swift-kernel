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
    /// Unified error type for all kernel syscalls.
    ///
    /// Aggregates domain-specific leaf errors into a single type for use in
    /// generic syscall contexts. Each case wraps the authoritative domain error.
    ///
    /// ## Design Principles
    /// - **Semantic, not platform-specific**: Cases represent user-actionable conditions.
    /// - **Typed throws**: No `rethrows`, no `any Error`.
    /// - **Domain leaf errors**: Each case wraps the domain's own error type.
    /// - **EOF is NOT an error**: `read`/`pread` return 0 on EOF.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Path resolution errors.
        case path(Kernel.Path.Resolution.Error)

        /// File descriptor/handle errors.
        case handle(Kernel.Descriptor.Validity.Error)

        /// I/O operation errors.
        /// Note: EOF is NOT an error. read/pread return 0 on EOF.
        case io(Kernel.IO.Error)

        /// File locking errors.
        case lock(Kernel.Lock.Error)

        /// Memory-related errors.
        case memory(Kernel.Memory.Error)

        /// Permission errors.
        case permission(Kernel.Permission.Error)

        /// Storage space errors.
        case space(Kernel.Storage.Error)

        /// Signal interruption errors.
        case signal(Kernel.Signal.Error)

        /// Non-blocking operation errors.
        case blocking(Kernel.IO.Blocking.Error)

        /// Unmapped platform-specific errors.
        case platform(Kernel.Errno.Unmapped.Error)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .path(let error):
            return "path: \(error)"
        case .handle(let error):
            return "handle: \(error)"
        case .io(let error):
            return "io: \(error)"
        case .lock(let error):
            return "lock: \(error)"
        case .memory(let error):
            return "memory: \(error)"
        case .permission(let error):
            return "permission: \(error)"
        case .space(let error):
            return "space: \(error)"
        case .signal(let error):
            return "signal: \(error)"
        case .blocking(let error):
            return "blocking: \(error)"
        case .platform(let error):
            return "\(error)"
        }
    }
}

#if !os(Windows)
import SystemPackage
#endif

#if os(Windows)
public import WinSDK
#endif

extension Kernel.Error {
    public init?(
        _ code: Kernel.Error.Code
    ){
        switch code {
        case .posix(let rawValue):
            #if !os(Windows)
            let errno = Errno(rawValue: rawValue)
            // Try each domain in priority order
            if let e = Kernel.Path.Resolution.Error(errno: errno) { self = .path(e) }
            if let e = Kernel.Permission.Error(errno: errno) { self = .permission(e) }
            if let e = Kernel.Descriptor.Validity.Error(errno: errno) { self = .handle(e) }
            if let e = Kernel.Signal.Error(errno: errno) { self = .signal(e) }
            if let e = Kernel.IO.Blocking.Error(errno: errno) { self = .blocking(e) }
            if let e = Kernel.Storage.Error(errno: errno) { self = .space(e) }
            if let e = Kernel.Memory.Error(errno: errno) { self = .memory(e) }
            if let e = Kernel.IO.Error(errno: errno) { self = .io(e) }
            if let e = Kernel.Lock.Error(errno: errno) { self = .lock(e) }
            #endif
            return nil

        case .win32(let code):
            #if os(Windows)
            // Explicit DWORD conversion to call existing mapping entry points
            let dword = DWORD(code)
            if let e = Kernel.Path.Resolution.Error(windowsError: dword) { self = .path(e) }
            if let e = Kernel.Permission.Error(windowsError: dword) { self = .permission(e) }
            if let e = Kernel.Descriptor.Validity.Error(windowsError: dword) { self = .handle(e) }
            if let e = Kernel.Storage.Error(windowsError: dword) { self = .space(e) }
            if let e = Kernel.Memory.Error(windowsError: dword) { self = .memory(e) }
            if let e = Kernel.IO.Error(windowsError: dword) { self = .io(e) }
            if let e = Kernel.Lock.Error(windowsError: dword) { self = .lock(e) }
            #endif
            return nil
        }
    }
}

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension Kernel.Error {
    /// Returns the platform error message for a given error code.
    ///
    /// On POSIX, calls `strerror` for `.posix` codes.
    /// On Windows, calls `FormatMessageW` for `.win32` codes.
    ///
    /// - Parameter code: The unified error code.
    /// - Returns: A human-readable error message, or `nil` if not available.
    public static func message(for code: Code) -> String? {
        switch code {
        case .posix(let rawValue):
            #if !os(Windows)
            return String(cString: strerror(rawValue))
            #else
            return nil
            #endif

        case .win32(let rawValue):
            #if os(Windows)
            let flags: DWORD =
                DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS)

            var buffer: LPWSTR? = nil

            let length: DWORD = withUnsafeMutablePointer(to: &buffer) { bufferPtr in
                bufferPtr.withMemoryRebound(to: WCHAR.self, capacity: 1) { widePtr in
                    FormatMessageW(
                        flags,
                        nil,
                        rawValue,
                        DWORD(MAKELANGID(WORD(LANG_NEUTRAL), WORD(SUBLANG_DEFAULT))),
                        widePtr,
                        0,
                        nil
                    )
                }
            }

            guard length > 0, let buffer else { return nil }
            defer { _ = LocalFree(buffer) }

            let u16 = UnsafeBufferPointer(start: buffer, count: Int(length))
            let message = String(decoding: u16, as: UTF16.self)
            return message.trimmingCharacters(in: .whitespacesAndNewlines)
            #else
            return nil
            #endif
        }
    }
}


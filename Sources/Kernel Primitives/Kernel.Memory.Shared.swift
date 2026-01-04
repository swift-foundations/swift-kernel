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
    /// Raw POSIX shared memory syscall wrappers.
    ///
    /// Provides policy-free access to shm_open and shm_unlink.
    /// Higher layers (swift-memory) build RAII and convenience on top.
    public enum Shared {}
}

// MARK: - Darwin Implementation

#if canImport(Darwin)

    public import Darwin
    public import CDarwinShim

    extension Kernel.Memory.Shared {
        /// Opens or creates a POSIX shared memory object.
        ///
        /// - Parameters:
        ///   - name: The name of the shared memory object (must start with '/').
        ///   - access: Read/write access mode.
        ///   - options: Creation options (create, exclusive, truncate).
        ///   - permissions: Permission mode for creation.
        /// - Returns: A file descriptor for the shared memory object.
        /// - Throws: `Error.open` on failure.
        @inlinable
        public static func open(
            name: UnsafePointer<CChar>,
            access: Access,
            options: Options = [],
            permissions: Kernel.File.Permissions = .ownerReadWrite
        ) throws(Error) -> Kernel.Descriptor {
            let flags = access.posixFlags | options.posixFlags
            // Use shim because Darwin declares shm_open as variadic
            let fd = swift_shm_open(name, flags, mode_t(permissions.rawValue))
            guard fd >= 0 else {
                throw .open(.captureErrno())
            }
            return Kernel.Descriptor(rawValue: fd)
        }

        /// Removes a POSIX shared memory object.
        ///
        /// - Parameter name: The name of the shared memory object to remove.
        /// - Throws: `Error.unlink` on failure.
        @inlinable
        public static func unlink(name: UnsafePointer<CChar>) throws(Error) {
            guard shm_unlink(name) == 0 else {
                throw .unlink(.captureErrno())
            }
        }
    }

#endif

// MARK: - Linux Implementation

#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Memory.Shared {
        /// Opens or creates a POSIX shared memory object.
        ///
        /// - Parameters:
        ///   - name: The name of the shared memory object (must start with '/').
        ///   - access: Read/write access mode.
        ///   - options: Creation options (create, exclusive, truncate).
        ///   - permissions: Permission mode for creation.
        /// - Returns: A file descriptor for the shared memory object.
        /// - Throws: `Error.open` on failure.
        @inlinable
        public static func open(
            name: UnsafePointer<CChar>,
            access: Access,
            options: Options = [],
            permissions: Kernel.File.Permissions = .ownerReadWrite
        ) throws(Error) -> Kernel.Descriptor {
            let flags = access.posixFlags | options.posixFlags
            let fd = shm_open(name, flags, mode_t(permissions.rawValue))
            guard fd >= 0 else {
                throw .open(.captureErrno())
            }
            return Kernel.Descriptor(rawValue: fd)
        }

        /// Removes a POSIX shared memory object.
        ///
        /// - Parameter name: The name of the shared memory object to remove.
        /// - Throws: `Error.unlink` on failure.
        @inlinable
        public static func unlink(name: UnsafePointer<CChar>) throws(Error) {
            guard shm_unlink(name) == 0 else {
                throw .unlink(.captureErrno())
            }
        }
    }

#endif

// MARK: - Windows Placeholder

#if os(Windows)

    // Windows uses CreateFileMapping with named objects for shared memory.
    // This requires different API design and is not directly compatible with POSIX shm.
    // For now, we don't provide Kernel.Memory.Shared on Windows.
    // A future version could add Kernel.Memory.Shared.Windows with platform-specific API.

#endif

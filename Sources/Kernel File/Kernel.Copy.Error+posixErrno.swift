// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Windows has no POSIX errno domain; this mapping is POSIX-only, matching
// the whole-file gating convention used elsewhere in this target for
// POSIX-only surfaces (e.g. Kernel.Event.Source+Kqueue.swift).
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        internal import Glibc
    #elseif canImport(Musl)
        internal import Musl
    #endif

    // MARK: - POSIX errno to Copy.Error Mapping

    extension Kernel.Copy.Error {
        /// Creates a copy error from a POSIX errno value.
        ///
        /// Maps standard POSIX error codes to domain-specific copy error cases.
        /// Unknown errors map to `.unsupported` as a fallback.
        ///
        /// - Parameter posixErrno: The POSIX errno value from a copy syscall.
        public init(posixErrno: Int32) {
            switch posixErrno {
            case EBADF:
                self = .invalidDescriptor

            case EXDEV:
                self = .crossDevice

            case ENOSPC:
                self = .noSpace

            case EIO:
                self = .io

            case EACCES, EPERM:
                self = .permissionDenied

            case ENOENT:
                self = .notFound

            case EEXIST:
                self = .exists

            case EINVAL, ENOTSUP:
                self = .unsupported

            default:
                self = .unsupported
            }
        }
    }

#endif

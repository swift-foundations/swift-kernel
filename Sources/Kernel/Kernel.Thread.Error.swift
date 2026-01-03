// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel.Thread {
    /// Errors from thread operations.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Thread creation failed.
        ///
        /// - On POSIX: The return value from `pthread_create` (e.g., EAGAIN, EPERM).
        /// - On Windows: The value from `GetLastError()`.
        case createFailed(code: Int32)

        /// Thread join failed.
        case joinFailed(code: Int32)

        /// Thread detach failed.
        case detachFailed(code: Int32)
    }
}

extension Kernel.Thread.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .createFailed(let code):
            #if os(Windows)
                return "CreateThread failed with error code \(code)"
            #else
                return "pthread_create failed with error code \(code)"
            #endif
        case .joinFailed(let code):
            #if os(Windows)
                return "WaitForSingleObject failed with error code \(code)"
            #else
                return "pthread_join failed with error code \(code)"
            #endif
        case .detachFailed(let code):
            #if os(Windows)
                return "CloseHandle failed with error code \(code)"
            #else
                return "pthread_detach failed with error code \(code)"
            #endif
        }
    }
}

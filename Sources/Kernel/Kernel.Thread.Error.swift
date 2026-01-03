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
        case create(Kernel.Error.Code)

        /// Thread join failed.
        case join(Kernel.Error.Code)

        /// Thread detach failed.
        case detach(Kernel.Error.Code)
    }
}

extension Kernel.Thread.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .create(let code):
            if let message = Kernel.Error.message(for: code) {
                return "thread creation failed: \(message)"
            }
            return "thread creation failed (\(code))"
        case .join(let code):
            if let message = Kernel.Error.message(for: code) {
                return "thread join failed: \(message)"
            }
            return "thread join failed (\(code))"
        case .detach(let code):
            if let message = Kernel.Error.message(for: code) {
                return "thread detach failed: \(message)"
            }
            return "thread detach failed (\(code))"
        }
    }
}

// MARK: - Kernel.Error Conversion

extension Kernel.Error {
    /// Creates a semantic error from a thread error.
    ///
    /// Maps to semantic cases where possible, falls back to `.platform` otherwise.
    public init(_ error: Kernel.Thread.Error) {
        let code: Kernel.Error.Code
        switch error {
        case .create(let c): code = c
        case .join(let c): code = c
        case .detach(let c): code = c
        }
        self = Kernel.Error(code) ?? .platform(Kernel.Errno.Unmapped.Error(code))
    }
}

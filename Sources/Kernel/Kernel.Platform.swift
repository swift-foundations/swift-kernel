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
    /// Platform domain - unmapped platform-specific errors.
    ///
    /// This is the escape hatch for errno/GetLastError codes that
    /// are not mapped to semantic error cases. Every syscall error
    /// type includes this as a case to ensure completeness.
    public enum Platform: Sendable {
        /// Platform-specific errors not mapped to semantic cases.
        public enum Error: Swift.Error, Sendable, Hashable {
            /// Unmapped platform error code.
            ///
            /// - Parameter code: The raw error code (errno on POSIX, GetLastError() on Windows).
            case unmapped(code: Int32)
        }
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Platform.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unmapped(let code):
            return "platform error \(code)"
        }
    }
}

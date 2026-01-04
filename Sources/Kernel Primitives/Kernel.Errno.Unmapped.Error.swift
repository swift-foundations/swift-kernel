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

extension Kernel.Errno.Unmapped {
    /// Platform-specific errors not mapped to semantic cases.
    public enum Error: Swift.Error, Sendable, Hashable {
        /// Unmapped platform error code.
        ///
        /// - Parameters:
        ///   - code: The unified platform error code.
        ///   - message: Optional diagnostic message (computed lazily, not required for propagation).
        case unmapped(code: Kernel.Error.Code, message: Swift.String?)
    }
}

// MARK: - CustomStringConvertible

extension Kernel.Errno.Unmapped.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .unmapped(let code, let message):
            if let message { return message }
            if let m = Kernel.Error.message(for: code) { return m }
            return "platform error \(code)"
        }
    }
}

// MARK: - Convenience Initializers

extension Kernel.Errno.Unmapped.Error {
    public init(_ code: Kernel.Error.Code) {
        self = .unmapped(code: code, message: nil)
    }
}

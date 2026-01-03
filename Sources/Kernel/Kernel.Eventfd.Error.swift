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

#if canImport(Glibc) || canImport(Musl)

extension Kernel.Eventfd {
    /// Errors from eventfd operations.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Failed to create eventfd.
        case create(Kernel.Error.Code)

        /// Failed to read from eventfd.
        case read(Kernel.Error.Code)

        /// Failed to write to eventfd.
        case write(Kernel.Error.Code)

        /// Operation would block (non-blocking mode).
        case wouldBlock
    }
}

extension Kernel.Eventfd.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .create(let code):
            return "eventfd creation failed (\(code))"
        case .read(let code):
            return "eventfd read failed (\(code))"
        case .write(let code):
            return "eventfd write failed (\(code))"
        case .wouldBlock:
            return "operation would block"
        }
    }
}

extension Kernel.Eventfd.Error {
    /// The error code associated with this error, if any.
    public var code: Kernel.Error.Code? {
        switch self {
        case .create(let code): return code
        case .read(let code): return code
        case .write(let code): return code
        case .wouldBlock: return nil
        }
    }
}

// MARK: - Kernel.Error Conversion

extension Kernel.Error {
    /// Creates a semantic error from an eventfd error.
    ///
    /// Maps to semantic cases where possible, falls back to `.platform` otherwise.
    public init(_ error: Kernel.Eventfd.Error) {
        switch error {
        case .create(let code):
            self = Kernel.Error(code) ?? .platform(Kernel.Platform.Error(code))
        case .read(let code):
            self = Kernel.Error(code) ?? .platform(Kernel.Platform.Error(code))
        case .write(let code):
            self = Kernel.Error(code) ?? .platform(Kernel.Platform.Error(code))
        case .wouldBlock:
            self = .blocking(.wouldBlock)
        }
    }
}

#endif

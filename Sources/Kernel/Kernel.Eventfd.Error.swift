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
        case create(errno: Int32)

        /// Failed to read from eventfd.
        case read(errno: Int32)

        /// Failed to write to eventfd.
        case write(errno: Int32)

        /// Operation would block (non-blocking mode).
        case wouldBlock
    }
}

extension Kernel.Eventfd.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .create(let errno):
            return "eventfd creation failed (errno: \(errno))"
        case .read(let errno):
            return "eventfd read failed (errno: \(errno))"
        case .write(let errno):
            return "eventfd write failed (errno: \(errno))"
        case .wouldBlock:
            return "operation would block"
        }
    }
}

extension Kernel.Eventfd.Error {
    /// The errno value associated with this error, if any.
    public var errno: Int32? {
        switch self {
        case .create(let code): return code
        case .read(let code): return code
        case .write(let code): return code
        case .wouldBlock: return nil
        }
    }

    /// Converts this eventfd error to a `Kernel.Error`.
    public var asKernelError: Kernel.Error {
        switch self {
        case .create(let errno):
            return .platform(code: errno)
        case .read(let errno):
            return .platform(code: errno)
        case .write(let errno):
            return .platform(code: errno)
        case .wouldBlock:
            return .resource(.blocked)
        }
    }
}

#endif

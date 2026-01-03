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

    extension Kernel.IOUring {
        /// Errors from io_uring operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create io_uring instance.
            case setup(errno: Int32)

            /// Failed to submit/wait (io_uring_enter).
            case enter(errno: Int32)

            /// Failed to register resources.
            case register(errno: Int32)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.IOUring.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .setup(let errno):
                return "io_uring_setup failed (errno: \(errno))"
            case .enter(let errno):
                return "io_uring_enter failed (errno: \(errno))"
            case .register(let errno):
                return "io_uring_register failed (errno: \(errno))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

    // MARK: - Kernel.Error Conversion

    extension Kernel.IOUring.Error {
        /// Converts this io_uring error to a `Kernel.Error`.
        ///
        /// Maps to semantic cases where possible, falls back to `.platform` otherwise.
        public var asKernelError: Kernel.Error {
            switch self {
            case .setup(let errno):
                return .platform(code: errno)
            case .enter(let errno):
                return .platform(code: errno)
            case .register(let errno):
                return .platform(code: errno)
            case .interrupted:
                return .resource(.interrupted)
            }
        }
    }

#endif

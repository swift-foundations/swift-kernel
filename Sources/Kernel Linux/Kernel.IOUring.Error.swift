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
public import Kernel_Primitives

#if canImport(Glibc) || canImport(Musl)

    extension Kernel.IOUring {
        /// Errors from io_uring operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create io_uring instance.
            case setup(Kernel.Error.Code)

            /// Failed to submit/wait (io_uring_enter).
            case enter(Kernel.Error.Code)

            /// Failed to register resources.
            case register(Kernel.Error.Code)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.IOUring.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .setup(let code):
                return "io_uring_setup failed (\(code))"
            case .enter(let code):
                return "io_uring_enter failed (\(code))"
            case .register(let code):
                return "io_uring_register failed (\(code))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

    // MARK: - Kernel.Error Conversion

    extension Kernel.Error {
        /// Creates a semantic error from an io_uring error.
        ///
        /// Maps to semantic cases where possible, falls back to `.platform` otherwise.
        public init(_ error: Kernel.IOUring.Error) {
            switch error {
            case .setup(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .enter(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .register(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .interrupted:
                self = .signal(.interrupted)
            }
        }
    }

#endif

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

#if canImport(Darwin)

    extension Kernel.Kqueue {
        /// Errors from kqueue operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create kqueue.
            case create(Kernel.Error.Code)

            /// Failed to register/modify events.
            case kevent(Kernel.Error.Code)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.Kqueue.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .create(let code):
                return "kqueue creation failed (\(code))"
            case .kevent(let code):
                return "kevent failed (\(code))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

#endif

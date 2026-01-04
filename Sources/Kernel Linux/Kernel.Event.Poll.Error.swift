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

    extension Kernel.Event.Poll {
        /// Errors from epoll operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create epoll instance.
            case create(Kernel.Error.Code)

            /// Failed to control epoll (add/modify/delete).
            case ctl(Kernel.Error.Code)

            /// Failed to wait for events.
            case wait(Kernel.Error.Code)

            /// Operation was interrupted by a signal.
            case interrupted
        }
    }

    extension Kernel.Event.Poll.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .create(let code):
                return "epoll_create1 failed (\(code))"
            case .ctl(let code):
                return "epoll_ctl failed (\(code))"
            case .wait(let code):
                return "epoll_wait failed (\(code))"
            case .interrupted:
                return "operation interrupted"
            }
        }
    }

#endif

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


#if os(Windows)

    extension Kernel.IOCP {
        /// Result of an overlapped write operation.
        public enum WriteResult: Sendable, Equatable {
            /// The operation is pending asynchronously.
            case pending
            /// The operation completed synchronously with the given byte count.
            case completed(bytes: UInt32)
        }
    }

#endif

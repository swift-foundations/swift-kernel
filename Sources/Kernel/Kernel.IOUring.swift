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

    extension Kernel {
        /// Raw io_uring syscall wrappers (Linux only).
        ///
        /// io_uring is a high-performance asynchronous I/O interface for Linux (kernel 5.1+).
        /// This namespace provides policy-free syscall wrappers.
        ///
        /// Higher layers (swift-io) build ring memory management, SQ/CQ indexing,
        /// and operation dispatch on top of these primitives.
        public enum IOUring {}
    }

#endif

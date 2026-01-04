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
        /// Opcodes for `io_uring_register`.
        public struct RegisterOpcode: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// Register buffers for zero-copy I/O.
            public static let registerBuffers = RegisterOpcode(rawValue: 0)

            /// Unregister previously registered buffers.
            public static let unregisterBuffers = RegisterOpcode(rawValue: 1)

            /// Register file descriptors.
            public static let registerFiles = RegisterOpcode(rawValue: 2)

            /// Unregister previously registered files.
            public static let unregisterFiles = RegisterOpcode(rawValue: 3)

            /// Register an eventfd for CQ notifications.
            public static let registerEventfd = RegisterOpcode(rawValue: 4)

            /// Unregister the eventfd.
            public static let unregisterEventfd = RegisterOpcode(rawValue: 5)

            /// Update registered files.
            public static let registerFilesUpdate = RegisterOpcode(rawValue: 6)

            /// Register eventfd for async notification.
            public static let registerEventfdAsync = RegisterOpcode(rawValue: 7)

            /// Probe supported operations.
            public static let registerProbe = RegisterOpcode(rawValue: 8)

            /// Register personality (credentials).
            public static let registerPersonality = RegisterOpcode(rawValue: 9)

            /// Unregister personality.
            public static let unregisterPersonality = RegisterOpcode(rawValue: 10)

            /// Enable a disabled ring.
            public static let enableRings = RegisterOpcode(rawValue: 11)
        }
    }

#endif

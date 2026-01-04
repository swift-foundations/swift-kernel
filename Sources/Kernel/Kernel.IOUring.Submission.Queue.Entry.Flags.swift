// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if canImport(Glibc) || canImport(Musl)

    extension Kernel.IOUring.Submission.Queue.Entry {
        /// Flags for submission queue entry behavior.
        public struct Flags: OptionSet, Sendable {
            public let rawValue: UInt8

            @inlinable
            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }

            /// Use fixed file descriptor from registered files.
            public static let fixedFile = Flags(rawValue: 1 << 0)

            /// Issue operation after previous entry completes.
            public static let ioLink = Flags(rawValue: 1 << 1)

            /// Like ioLink, but also links on failure.
            public static let ioHardlink = Flags(rawValue: 1 << 2)

            /// Force async execution (never complete inline).
            public static let async = Flags(rawValue: 1 << 3)

            /// Select buffer from provided buffer group.
            public static let bufferSelect = Flags(rawValue: 1 << 4)

            /// Don't post completion entry if operation completes successfully (kernel 5.17+).
            public static let cqeSkipSuccess = Flags(rawValue: 1 << 5)
        }
    }

#endif

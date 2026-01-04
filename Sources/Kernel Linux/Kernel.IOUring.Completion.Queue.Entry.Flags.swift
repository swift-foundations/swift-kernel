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
public import Kernel_Primitives

#if canImport(Glibc) || canImport(Musl)

    extension Kernel.IOUring.Completion.Queue.Entry {
        /// Flags returned with completion queue entries.
        public struct Flags: OptionSet, Sendable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }
        }
    }

    extension Kernel.IOUring.Completion.Queue.Entry.Flags {
        /// Buffer ID is valid (buffer was selected from buffer group).
        public static let buffer = Self(rawValue: 1 << 0)

        /// More entries will follow for this submission (multishot).
        public static let more = Self(rawValue: 1 << 1)

        /// Socket is in a readable state (recv multishot).
        public static let sockNonempty = Self(rawValue: 1 << 2)

        /// Notification entry (not a completion).
        public static let notif = Self(rawValue: 1 << 3)
    }

#endif

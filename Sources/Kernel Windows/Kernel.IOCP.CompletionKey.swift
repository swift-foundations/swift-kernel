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
    public import WinSDK

    extension Kernel.IOCP {
        /// Completion key for identifying handles.
        ///
        /// The completion key is an application-defined value associated with
        /// a file handle when it's registered with an IOCP.
        public struct CompletionKey: RawRepresentable, Sendable, Equatable, Hashable {
            public let rawValue: ULONG_PTR

            @inlinable
            public init(rawValue: ULONG_PTR) {
                self.rawValue = rawValue
            }
        }
    }

#endif

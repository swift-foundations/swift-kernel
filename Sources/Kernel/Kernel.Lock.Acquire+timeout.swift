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

#if KERNEL_AVAILABLE && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD) || os(Windows))

extension Kernel.Lock.Acquire {
    /// Creates a deadline-based acquisition from a duration.
    ///
    /// - Parameter duration: The maximum time to wait.
    /// - Returns: An acquisition strategy with a deadline.
    public static func timeout(_ duration: Duration) -> Self {
        .deadline(Clock.Continuous.now.advanced(by: duration))
    }
}

#endif

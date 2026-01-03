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
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension Kernel.Error {
    #if !os(Windows)
    /// Returns the platform error message for a given errno value.
    ///
    /// This is equivalent to the POSIX `strerror()` function but exposed
    /// through Kernel so callers don't need to import Darwin/Glibc.
    ///
    /// - Parameter errno: The error number.
    /// - Returns: A human-readable error message.
    public static func message(for errno: Int32) -> String {
        String(cString: strerror(errno))
    }
    #endif
}

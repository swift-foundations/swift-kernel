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
#elseif os(Windows)
    import WinSDK
#endif

extension Kernel {
    /// System limits and constants.
    public enum Limits {
        /// Platform path length limit.
        ///
        /// Falls back to 4096 if the platform constant is undefined.
        /// Note: This is a conservative limit, not a universal truth.
        /// Extended-length paths on Windows can exceed MAX_PATH.
        public static var pathMax: Int {
            #if os(Windows)
                return Int(MAX_PATH)  // 260
            #elseif canImport(Darwin)
                return Int(PATH_MAX)  // 1024
            #elseif canImport(Glibc) || canImport(Musl)
                return Int(PATH_MAX)  // Usually 4096
            #else
                return 4096  // Conservative fallback
            #endif
        }
    }
}

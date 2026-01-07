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

@_exported public import Kernel_Primitives
@_exported public import StandardsCollections

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel
#endif

#if canImport(Darwin)
    @_exported public import Darwin_Kernel
#elseif canImport(Glibc) || canImport(Musl)
    @_exported public import Linux_Kernel
#elseif os(Windows)
    @_exported public import Windows_Kernel
#endif

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

#if canImport(Darwin)
    @_exported public import Kernel_Darwin
#elseif canImport(Glibc) || canImport(Musl)
    @_exported public import Kernel_Linux
#elseif os(Windows)
    @_exported public import Kernel_Windows
#endif

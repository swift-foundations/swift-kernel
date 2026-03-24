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
@_exported public import System_Primitives
@_exported public import Queue_Primitives
@_exported public import Dimension_Primitives
@_exported public import Reference_Primitives
@_exported public import Ownership_Primitives

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD)
    @_exported public import POSIX_Kernel
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @_exported public import Darwin_Kernel
    @_exported public import Darwin_System
#elseif os(Linux) || os(Android) || os(OpenBSD)
    @_exported public import Linux_Kernel
    @_exported public import Linux_System
#elseif os(Windows)
    @_exported public import Windows_Kernel
#endif

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
import StandardsTestSupport
import Testing

@testable import Kernel_Darwin
import Kernel_Primitives

// Kernel.Kqueue.Event.Data is a typealias to Tagged<Kernel.Kqueue.Event, UInt64>
// #TestSuites cannot be used on typealiases
#endif

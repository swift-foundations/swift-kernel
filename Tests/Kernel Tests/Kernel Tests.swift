//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import StandardsTestSupport
import Testing

@testable import Kernel

extension Kernel {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Test.Unit {
    @Test("Kernel namespace exists")
    func namespaceExists() {
        // Kernel is an enum namespace, verify it compiles
        _ = Kernel.self
    }
}

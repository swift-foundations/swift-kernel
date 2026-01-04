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

import StandardsTestSupport
import Testing

@testable import Kernel_Primitives

extension Kernel.Errno.Unmapped {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Errno.Unmapped.Test.Unit {
    @Test("Unmapped namespace exists")
    func namespaceExists() {
        _ = Kernel.Errno.Unmapped.self
    }

    @Test("Unmapped is an enum")
    func isEnum() {
        let _: Kernel.Errno.Unmapped.Type = Kernel.Errno.Unmapped.self
    }
}

// MARK: - Nested Types

extension Kernel.Errno.Unmapped.Test.Unit {
    @Test("Unmapped.Error type exists")
    func errorTypeExists() {
        let _: Kernel.Errno.Unmapped.Error.Type = Kernel.Errno.Unmapped.Error.self
    }
}

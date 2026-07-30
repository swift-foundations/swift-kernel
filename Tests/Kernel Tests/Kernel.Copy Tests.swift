// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Kernel
import Tagged_Primitives_Standard_Library_Integration
// Tests use Apple native Testing framework
import Testing

extension Kernel.Copy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit Tests

extension Kernel.Copy.Test.Unit {
    @Test
    func `Copy namespace exists`() {
        // Kernel.Copy is a public enum namespace
        _ = Kernel.Copy.self
    }

    @Test
    func `Copy is an enum`() {
        let _: Kernel.Copy.Type = Kernel.Copy.self
    }

    @Test
    func `Copy is Sendable`() {
        let _: any Sendable.Type = Kernel.Copy.self
    }
}

// MARK: - Nested Types

extension Kernel.Copy.Test.Unit {
    @Test
    func `Copy.Error type exists`() {
        let _: Kernel.Copy.Error.Type = Kernel.Copy.Error.self
    }

    #if os(Linux) || canImport(Darwin)
        @Test
        func `Copy.Clone namespace exists`() {
            let _: Kernel.Copy.Clone.Type = Kernel.Copy.Clone.self
        }
    #endif

    #if os(Linux)
        @Test
        func `Copy.Range namespace exists on Linux`() {
            let _: Kernel.Copy.Range.Type = Kernel.Copy.Range.self
        }
    #endif
}

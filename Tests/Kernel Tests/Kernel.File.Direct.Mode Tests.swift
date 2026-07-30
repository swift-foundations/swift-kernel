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

extension Kernel.File.Direct.Mode {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit Tests

extension Kernel.File.Direct.Mode.Test.Unit {
    @Test
    func `direct case exists`() {
        let mode = Kernel.File.Direct.Mode.direct
        if case .direct = mode {
            // Expected
        } else {
            Issue.record("Expected .direct case")
        }
    }

    @Test
    func `uncached case exists`() {
        let mode = Kernel.File.Direct.Mode.uncached
        if case .uncached = mode {
            // Expected
        } else {
            Issue.record("Expected .uncached case")
        }
    }

    @Test
    func `buffered case exists`() {
        let mode = Kernel.File.Direct.Mode.buffered
        if case .buffered = mode {
            // Expected
        } else {
            Issue.record("Expected .buffered case")
        }
    }

    @Test
    func `auto case exists`() {
        let mode = Kernel.File.Direct.Mode.auto(policy: .fallbackToBuffered)
        if case .auto = mode {
            // Expected
        } else {
            Issue.record("Expected .auto case")
        }
    }
}

// MARK: - Conformance Tests

extension Kernel.File.Direct.Mode.Test.Unit {
    @Test
    func `Mode is Sendable`() {
        let mode: any Sendable = Kernel.File.Direct.Mode.buffered
        #expect(mode is Kernel.File.Direct.Mode)
    }

    @Test
    func `Mode is Equatable`() {
        let a = Kernel.File.Direct.Mode.buffered
        let b = Kernel.File.Direct.Mode.buffered
        let c = Kernel.File.Direct.Mode.direct
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - Nested Types

extension Kernel.File.Direct.Mode.Test.Unit {
    @Test
    func `Mode.Policy type exists`() {
        let _: Kernel.File.Direct.Mode.Policy.Type = Kernel.File.Direct.Mode.Policy.self
    }

    @Test
    func `Mode.Resolved type exists`() {
        let _: Kernel.File.Direct.Mode.Resolved.Type = Kernel.File.Direct.Mode.Resolved.self
    }
}

// MARK: - Edge Cases

extension Kernel.File.Direct.Mode.Test.EdgeCase {
    @Test
    func `all simple cases are distinct`() {
        let cases: [Kernel.File.Direct.Mode] = [
            .direct,
            .uncached,
            .buffered,
        ]

        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j])
            }
        }
    }

    @Test
    func `auto with different policies are distinct`() {
        let fallback = Kernel.File.Direct.Mode.auto(policy: .fallbackToBuffered)
        let error = Kernel.File.Direct.Mode.auto(policy: .errorOnViolation)
        #expect(fallback != error)
    }
}

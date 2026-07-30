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

extension Kernel.File.Direct.Error.Operation {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit Tests

extension Kernel.File.Direct.Error.Operation.Test.Unit {
    @Test
    func `open case exists`() {
        let operation = Kernel.File.Direct.Error.Operation.open
        if case .open = operation {
            // Expected
        } else {
            Issue.record("Expected .open case")
        }
    }

    @Test
    func `cache case exists`() {
        let operation = Kernel.File.Direct.Error.Operation.cache(.set)
        if case .cache = operation {
            // Expected
        } else {
            Issue.record("Expected .cache case")
        }
    }

    @Test
    func `sector case exists`() {
        let operation = Kernel.File.Direct.Error.Operation.sector(.getSize)
        if case .sector = operation {
            // Expected
        } else {
            Issue.record("Expected .sector case")
        }
    }

    @Test
    func `read case exists`() {
        let operation = Kernel.File.Direct.Error.Operation.read
        if case .read = operation {
            // Expected
        } else {
            Issue.record("Expected .read case")
        }
    }

    @Test
    func `write case exists`() {
        let operation = Kernel.File.Direct.Error.Operation.write
        if case .write = operation {
            // Expected
        } else {
            Issue.record("Expected .write case")
        }
    }
}

// MARK: - Nested Type Tests

extension Kernel.File.Direct.Error.Operation.Test.Unit {
    @Test
    func `Cache.set case exists`() {
        let cache = Kernel.File.Direct.Error.Operation.Cache.set
        #expect(cache.rawValue == "set")
    }

    @Test
    func `Cache.clear case exists`() {
        let cache = Kernel.File.Direct.Error.Operation.Cache.clear
        #expect(cache.rawValue == "clear")
    }

    @Test
    func `Sector.getSize case exists`() {
        let sector = Kernel.File.Direct.Error.Operation.Sector.getSize
        #expect(sector.rawValue == "getSize")
    }
}

// MARK: - Conformance Tests

extension Kernel.File.Direct.Error.Operation.Test.Unit {
    @Test
    func `Operation is Sendable`() {
        let operation: any Sendable = Kernel.File.Direct.Error.Operation.open
        #expect(operation is Kernel.File.Direct.Error.Operation)
    }

    @Test
    func `Operation is Equatable`() {
        let a = Kernel.File.Direct.Error.Operation.open
        let b = Kernel.File.Direct.Error.Operation.open
        let c = Kernel.File.Direct.Error.Operation.read
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `Cache is Sendable`() {
        let cache: any Sendable = Kernel.File.Direct.Error.Operation.Cache.set
        #expect(cache is Kernel.File.Direct.Error.Operation.Cache)
    }

    @Test
    func `Cache is Equatable`() {
        let a = Kernel.File.Direct.Error.Operation.Cache.set
        let b = Kernel.File.Direct.Error.Operation.Cache.set
        let c = Kernel.File.Direct.Error.Operation.Cache.clear
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `Sector is Sendable`() {
        let sector: any Sendable = Kernel.File.Direct.Error.Operation.Sector.getSize
        #expect(sector is Kernel.File.Direct.Error.Operation.Sector)
    }
}

// MARK: - Edge Cases

extension Kernel.File.Direct.Error.Operation.Test.EdgeCase {
    @Test
    func `all simple operations are distinct`() {
        let open = Kernel.File.Direct.Error.Operation.open
        let read = Kernel.File.Direct.Error.Operation.read
        let write = Kernel.File.Direct.Error.Operation.write
        #expect(open != read)
        #expect(read != write)
        #expect(open != write)
    }

    @Test
    func `cache operations with different types are distinct`() {
        let cacheSet = Kernel.File.Direct.Error.Operation.cache(.set)
        let cacheClear = Kernel.File.Direct.Error.Operation.cache(.clear)
        #expect(cacheSet != cacheClear)
    }
}

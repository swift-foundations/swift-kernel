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
import SystemPackage
import Testing

@testable import Kernel

extension Kernel.Path {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Path.Test.Unit {
    @Test("Path stores C string pointer")
    func storesCString() {
        "/tmp/test".withCString { cString in
            let path = Kernel.Path(unsafeCString: cString)
            #expect(path.cString == cString)
        }
    }

    @Test("Path is non-Copyable")
    func isNonCopyable() {
        // This test verifies compilation behavior
        // Kernel.Path: ~Copyable means it cannot be copied
        "/tmp/test".withCString { cString in
            let path = Kernel.Path(unsafeCString: cString)
            // Cannot do: let copy = path (would not compile)
            _ = path.cString
        }
    }
}

// MARK: - Edge Cases

extension Kernel.Path.Test.EdgeCase {
    @Test("Path with empty string")
    func emptyString() {
        "".withCString { cString in
            let path = Kernel.Path(unsafeCString: cString)
            #expect(path.cString == cString)
        }
    }
}

// MARK: - withPath Tests

extension Kernel.Test.Unit {
    @Test("withPath converts FilePath to Kernel.Path")
    func withPathConversion() throws {
        let filePath = FilePath("/tmp/test")
        try Kernel.withPath(filePath) { path in
            // Verify we can access the C string
            _ = path.cString
        }
    }

    @Test("withPath body receives valid C string")
    func withPathValidCString() throws {
        let filePath = FilePath("/tmp/test")
        try Kernel.withPath(filePath) { path in
            let string = String(cString: path.cString)
            #expect(string == "/tmp/test")
        }
    }
}

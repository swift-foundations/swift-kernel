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

extension Kernel.Lock {
    #TestSuites
}

// MARK: - Range Unit Tests

extension Kernel.Lock.Test.Unit {
    @Test("Range.file is equatable")
    func rangeFileEquatable() {
        let r1 = Kernel.Lock.Range.file
        let r2 = Kernel.Lock.Range.file
        #expect(r1 == r2)
    }

    @Test("Range.bytes is equatable")
    func rangeBytesEquatable() {
        let r1 = Kernel.Lock.Range.bytes(start: Kernel.File.Offset(10), end: Kernel.File.Offset(110))
        let r2 = Kernel.Lock.Range.bytes(start: Kernel.File.Offset(10), end: Kernel.File.Offset(110))
        let r3 = Kernel.Lock.Range.bytes(start: Kernel.File.Offset(20), end: Kernel.File.Offset(120))

        #expect(r1 == r2)
        #expect(r1 != r3)
    }

    @Test("Range.file and Range.bytes are not equal")
    func rangeFileVsBytes() {
        let file = Kernel.Lock.Range.file
        let bytes = Kernel.Lock.Range.bytes(start: .zero, end: .zero)

        #expect(file != bytes)
    }

    @Test("Range.bytes with length convenience")
    func rangeBytesWithLength() {
        let range = Kernel.Lock.Range.bytes(start: Kernel.File.Offset(100), length: Kernel.File.Size(100))
        #expect(range == .bytes(start: Kernel.File.Offset(100), end: Kernel.File.Offset(200)))
    }
}

// MARK: - Kind Unit Tests

extension Kernel.Lock.Test.Unit {
    @Test("Kind.shared and Kind.exclusive")
    func kindValues() {
        let shared = Kernel.Lock.Kind.shared
        let exclusive = Kernel.Lock.Kind.exclusive

        #expect(shared != exclusive)
        #expect(shared == .shared)
        #expect(exclusive == .exclusive)
    }
}

// MARK: - Hashable Tests

extension Kernel.Lock.Test.Unit {
    @Test("Range is hashable")
    func rangeHashable() {
        var set = Set<Kernel.Lock.Range>()
        set.insert(.file)
        set.insert(.bytes(start: Kernel.File.Offset(10), end: Kernel.File.Offset(30)))
        set.insert(.bytes(start: Kernel.File.Offset(10), end: Kernel.File.Offset(30)))  // Duplicate

        #expect(set.count == 2)
    }

    @Test("Kind is hashable")
    func kindHashable() {
        var set = Set<Kernel.Lock.Kind>()
        set.insert(.shared)
        set.insert(.exclusive)
        set.insert(.shared)  // Duplicate

        #expect(set.count == 2)
    }
}

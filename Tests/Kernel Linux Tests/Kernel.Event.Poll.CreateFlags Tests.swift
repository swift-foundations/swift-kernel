// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if os(Linux)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

import StandardsTestSupport
import Testing

@testable import Kernel_Linux
import Kernel_Primitives

extension Kernel.Event.Poll.CreateFlags {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Event.Poll.CreateFlags.Test.Unit {
    @Test("init with rawValue stores value")
    func initWithRawValue() {
        let flags = Kernel.Event.Poll.CreateFlags(rawValue: 42)
        #expect(flags.rawValue == 42)
    }

    @Test("none has rawValue of 0")
    func noneHasZeroRawValue() {
        #expect(Kernel.Event.Poll.CreateFlags.none.rawValue == 0)
    }

    @Test("cloexec matches EPOLL_CLOEXEC")
    func cloexecMatchesConstant() {
        #expect(Kernel.Event.Poll.CreateFlags.cloexec.rawValue == Int32(EPOLL_CLOEXEC))
    }

    @Test("flags can be combined with |")
    func flagsCombineWithOr() {
        let combined = Kernel.Event.Poll.CreateFlags.cloexec | Kernel.Event.Poll.CreateFlags.none
        #expect(combined.rawValue == Kernel.Event.Poll.CreateFlags.cloexec.rawValue)
    }

    @Test("rawValue roundtrip preserves value")
    func rawValueRoundtrip() {
        let original: Int32 = 0x7FFFFFFF
        let flags = Kernel.Event.Poll.CreateFlags(rawValue: original)
        #expect(flags.rawValue == original)
    }
}

// MARK: - Conformance Tests

extension Kernel.Event.Poll.CreateFlags.Test.Unit {
    @Test("CreateFlags is Sendable")
    func isSendable() {
        let flags: any Sendable = Kernel.Event.Poll.CreateFlags.cloexec
        #expect(flags is Kernel.Event.Poll.CreateFlags)
    }

    @Test("CreateFlags is Equatable")
    func isEquatable() {
        let a = Kernel.Event.Poll.CreateFlags.cloexec
        let b = Kernel.Event.Poll.CreateFlags.cloexec
        let c = Kernel.Event.Poll.CreateFlags.none
        #expect(a == b)
        #expect(a != c)
    }

    @Test("CreateFlags is Hashable")
    func isHashable() {
        var set = Set<Kernel.Event.Poll.CreateFlags>()
        set.insert(.cloexec)
        set.insert(.none)
        set.insert(.cloexec) // duplicate
        #expect(set.count == 2)
    }
}

// MARK: - Edge Cases

extension Kernel.Event.Poll.CreateFlags.Test.EdgeCase {
    @Test("combining same flag is idempotent")
    func combiningIdempotent() {
        let combined = Kernel.Event.Poll.CreateFlags.cloexec | .cloexec
        #expect(combined == .cloexec)
    }

    @Test("combining with none is identity")
    func combiningWithNoneIsIdentity() {
        let combined = Kernel.Event.Poll.CreateFlags.cloexec | .none
        #expect(combined == .cloexec)
    }

    @Test("none combined with none is none")
    func noneCombinedWithNone() {
        let combined = Kernel.Event.Poll.CreateFlags.none | .none
        #expect(combined == .none)
    }
}
#endif

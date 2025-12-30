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

extension Kernel.Stat {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Stat.Test.Unit {
    @Test("Stat stores all fields")
    func storesAllFields() {
        let time = Kernel.Time(seconds: 1000)
        let stat = Kernel.Stat(
            size: 1024,
            type: .regular,
            permissions: 0o644,
            uid: 501,
            gid: 20,
            inode: 12345,
            device: 1,
            linkCount: 1,
            accessTime: time,
            modificationTime: time,
            changeTime: time
        )

        #expect(stat.size == 1024)
        #expect(stat.type == .regular)
        #expect(stat.permissions == 0o644)
        #expect(stat.uid == 501)
        #expect(stat.gid == 20)
        #expect(stat.inode == 12345)
        #expect(stat.device == 1)
        #expect(stat.linkCount == 1)
    }

    @Test("Stat is Sendable")
    func isSendable() {
        let time = Kernel.Time(seconds: 0)
        let stat: any Sendable = Kernel.Stat(
            size: 0,
            type: .regular,
            permissions: 0,
            uid: 0,
            gid: 0,
            inode: 0,
            device: 0,
            linkCount: 0,
            accessTime: time,
            modificationTime: time,
            changeTime: time
        )
        #expect(stat is Kernel.Stat)
    }

    @Test("Stat is Equatable")
    func isEquatable() {
        let time = Kernel.Time(seconds: 0)
        let a = Kernel.Stat(
            size: 100,
            type: .regular,
            permissions: 0o644,
            uid: 0,
            gid: 0,
            inode: 1,
            device: 1,
            linkCount: 1,
            accessTime: time,
            modificationTime: time,
            changeTime: time
        )
        let b = Kernel.Stat(
            size: 100,
            type: .regular,
            permissions: 0o644,
            uid: 0,
            gid: 0,
            inode: 1,
            device: 1,
            linkCount: 1,
            accessTime: time,
            modificationTime: time,
            changeTime: time
        )

        #expect(a == b)
    }
}

// MARK: - Kind Unit Tests

extension Kernel.Stat.Test.Unit {
    @Test("Kind cases are distinct")
    func kindCasesDistinct() {
        let cases: [Kernel.Stat.Kind] = [
            .regular,
            .directory,
            .link(.symbolic),
            .device(.block),
            .device(.character),
            .fifo,
            .socket,
            .unknown,
        ]

        for (i, a) in cases.enumerated() {
            for (j, b) in cases.enumerated() {
                if i != j {
                    #expect(a != b, "Kind cases at \(i) and \(j) should differ")
                }
            }
        }
    }

    @Test("Kind is Sendable")
    func kindIsSendable() {
        let kind: any Sendable = Kernel.Stat.Kind.regular
        #expect(kind is Kernel.Stat.Kind)
    }

    @Test("Kind is Hashable")
    func kindIsHashable() {
        let a = Kernel.Stat.Kind.regular
        let b = Kernel.Stat.Kind.regular

        #expect(a.hashValue == b.hashValue)
    }

    @Test("Kind.Link cases")
    func kindLinkCases() {
        let symbolic = Kernel.Stat.Kind.Link.symbolic
        #expect(symbolic == .symbolic)
    }

    @Test("Kind.Device cases are distinct")
    func kindDeviceCases() {
        let block = Kernel.Stat.Kind.Device.block
        let character = Kernel.Stat.Kind.Device.character
        #expect(block != character)
    }
}

// MARK: - Edge Cases

extension Kernel.Stat.Test.EdgeCase {
    @Test("zero size file")
    func zeroSize() {
        let time = Kernel.Time(seconds: 0)
        let stat = Kernel.Stat(
            size: 0,
            type: .regular,
            permissions: 0,
            uid: 0,
            gid: 0,
            inode: 0,
            device: 0,
            linkCount: 0,
            accessTime: time,
            modificationTime: time,
            changeTime: time
        )

        #expect(stat.size == 0)
    }

    @Test("maximum permissions")
    func maxPermissions() {
        let time = Kernel.Time(seconds: 0)
        let stat = Kernel.Stat(
            size: 0,
            type: .regular,
            permissions: 0o7777,
            uid: 0,
            gid: 0,
            inode: 0,
            device: 0,
            linkCount: 0,
            accessTime: time,
            modificationTime: time,
            changeTime: time
        )

        #expect(stat.permissions == 0o7777)
    }
}

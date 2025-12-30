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

@testable import Kernel

extension Kernel.File.Open {
    #TestSuites
}

// MARK: - Mode Unit Tests

extension Kernel.File.Open.Test.Unit {
    @Test("Mode is OptionSet")
    func modeIsOptionSet() {
        let mode: Kernel.File.Open.Mode = [.read, .write]
        #expect(mode.contains(.read))
        #expect(mode.contains(.write))
    }

    @Test("Mode options are distinct")
    func modeOptionsDistinct() {
        let read = Kernel.File.Open.Mode.read
        let write = Kernel.File.Open.Mode.write

        #expect(read != write)
        #expect(!read.intersection(write).contains(.read))
    }

    @Test("Mode is Sendable")
    func modeIsSendable() {
        let mode: any Sendable = Kernel.File.Open.Mode.read
        #expect(mode is Kernel.File.Open.Mode)
    }

    @Test("Mode can combine read and write")
    func modeCombine() {
        let combined: Kernel.File.Open.Mode = [.read, .write]
        #expect(combined.contains(.read))
        #expect(combined.contains(.write))
    }
}

// MARK: - Options Unit Tests

extension Kernel.File.Open.Test.Unit {
    @Test("Options is OptionSet")
    func optionsIsOptionSet() {
        let options: Kernel.File.Open.Options = [.create, .truncate]
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
        #expect(!options.contains(.append))
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options: any Sendable = Kernel.File.Open.Options.create
        #expect(options is Kernel.File.Open.Options)
    }

    @Test("Options can be combined")
    func optionsCombine() {
        let combined = Kernel.File.Open.Options.create.union(.exclusive)
        #expect(combined.contains(.create))
        #expect(combined.contains(.exclusive))
    }

    @Test("all standard options are distinct")
    func standardOptionsDistinct() {
        let options: [Kernel.File.Open.Options] = [
            .create,
            .truncate,
            .append,
            .exclusive,
            .direct,
        ]

        for (i, a) in options.enumerated() {
            for (j, b) in options.enumerated() {
                if i != j {
                    #expect(!a.intersection(b).contains(a), "Options at index \(i) and \(j) should be distinct")
                }
            }
        }
    }
}

// MARK: - Edge Cases

extension Kernel.File.Open.Test.EdgeCase {
    @Test("empty options has zero raw value")
    func emptyOptions() {
        let empty = Kernel.File.Open.Options()
        #expect(empty.rawValue == 0)
    }

    @Test("exclusive without create is valid but semantically requires create")
    func exclusiveWithoutCreate() {
        // exclusive alone is valid at the API level
        let options = Kernel.File.Open.Options.exclusive
        #expect(options.contains(.exclusive))
        #expect(!options.contains(.create))
    }
}

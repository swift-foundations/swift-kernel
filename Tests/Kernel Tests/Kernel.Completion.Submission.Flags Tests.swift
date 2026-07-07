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

import Kernel_Test_Support
import Testing

@testable import Kernel

// MARK: - Kernel.Completion.Submission.Flags Tests (Linux only)

#if os(Linux)

    extension Kernel.Completion.Submission.Flags {
        @Suite struct Test {
            @Suite struct Unit {}
        }
    }

    extension Kernel.Completion.Submission.Flags.Test.Unit {
        @Test func `bufferSelect is nonzero`() {
            let flags = Kernel.Completion.Submission.Flags.bufferSelect
            #expect(flags.rawValue != 0)
        }

        @Test func `linked is nonzero`() {
            let flags = Kernel.Completion.Submission.Flags.linked
            #expect(flags.rawValue != 0)
        }

        @Test func `drain is nonzero`() {
            let flags = Kernel.Completion.Submission.Flags.drain
            #expect(flags.rawValue != 0)
        }

        @Test func `fixedFile is nonzero`() {
            let flags = Kernel.Completion.Submission.Flags.fixedFile
            #expect(flags.rawValue != 0)
        }

        @Test func `flag constants are distinct`() {
            let values: [UInt32] = [
                Kernel.Completion.Submission.Flags.bufferSelect.rawValue,
                Kernel.Completion.Submission.Flags.linked.rawValue,
                Kernel.Completion.Submission.Flags.drain.rawValue,
                Kernel.Completion.Submission.Flags.fixedFile.rawValue,
            ]

            let unique = Set(values)
            #expect(unique.count == values.count)
        }

        @Test func `each flag is a power of two`() {
            let flags: [Kernel.Completion.Submission.Flags] = [
                .bufferSelect,
                .linked,
                .drain,
                .fixedFile,
            ]

            for flag in flags {
                let raw = flag.rawValue
                #expect(raw.nonzeroBitCount == 1)
            }
        }
    }

#endif

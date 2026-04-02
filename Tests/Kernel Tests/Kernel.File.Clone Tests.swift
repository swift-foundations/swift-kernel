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

import Kernel
import Kernel_Primitives
import Kernel_Test_Support
import Testing

// MARK: - Ergonomic API Tests
//
// These tests verify the ergonomic layer types and error handling.
// Syscall behavior tests are in swift-iso-9945 (POSIX Kernel Primitives Tests).

@Suite("Kernel.File.Clone")
struct KernelFileCloneTests {

    // MARK: - Type Tests

    @Suite("Types")
    struct TypeTests {

        @Test("Capability enum values")
        func capabilityValues() {
            let reflink = Kernel.File.Clone.Capability.reflink
            let none = Kernel.File.Clone.Capability.none

            #expect(reflink != none)
            #expect(reflink == .reflink)
            #expect(none == .none)
        }

        @Test("Behavior enum values")
        func behaviorValues() {
            let reflinkOrFail = Kernel.File.Clone.Behavior.reflinkOrFail
            let reflinkOrCopy = Kernel.File.Clone.Behavior.reflinkOrCopy
            let copyOnly = Kernel.File.Clone.Behavior.copyOnly

            #expect(reflinkOrFail != reflinkOrCopy)
            #expect(reflinkOrCopy != copyOnly)
            #expect(reflinkOrFail != copyOnly)
        }

        @Test("Result enum values")
        func resultValues() {
            let reflinked = Kernel.File.Clone.Result.reflinked
            let copied = Kernel.File.Clone.Result.copied

            #expect(reflinked != copied)
        }

        @Test("types are Sendable")
        func typesAreSendable() {
            let cap: Kernel.File.Clone.Capability = .reflink
            let behavior: Kernel.File.Clone.Behavior = .reflinkOrCopy
            let result: Kernel.File.Clone.Result = .copied

            Task.detached {
                _ = cap
                _ = behavior
                _ = result
            }
        }
    }

    // MARK: - Error Tests

    @Suite("Error")
    struct ErrorTests {

        @Test("error descriptions are meaningful")
        func errorDescriptions() {
            let errors: [Kernel.File.Clone.Error] = [
                .notSupported,
                .crossDevice,
                .sourceNotFound,
                .destinationExists,
                .permissionDenied,
                .isDirectory,
                .platform(code: .posix(42), operation: .copy),
            ]

            for error in errors {
                let description = error.description
                #expect(!description.isEmpty)
            }

            #expect(Kernel.File.Clone.Error.notSupported.description.contains("not supported"))
            #expect(Kernel.File.Clone.Error.crossDevice.description.contains("different"))
        }

        @Test("error is Equatable")
        func errorEquatable() {
            #expect(Kernel.File.Clone.Error.notSupported == .notSupported)
            #expect(Kernel.File.Clone.Error.crossDevice != .notSupported)

            let p1 = Kernel.File.Clone.Error.platform(code: .posix(1), operation: .copy)
            let p2 = Kernel.File.Clone.Error.platform(code: .posix(1), operation: .copy)
            let p3 = Kernel.File.Clone.Error.platform(code: .posix(2), operation: .copy)

            #expect(p1 == p2)
            #expect(p1 != p3)
        }
    }
}

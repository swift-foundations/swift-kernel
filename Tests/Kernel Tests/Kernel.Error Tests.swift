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

extension Kernel.Error {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Error.Test.Unit {
    @Test("error conforms to Swift.Error")
    func conformsToError() {
        let error: any Swift.Error = Kernel.Error.notFound
        #expect(error is Kernel.Error)
    }

    @Test("error is Sendable")
    func isSendable() {
        let error: any Sendable = Kernel.Error.notFound
        #expect(error is Kernel.Error)
    }

    @Test("error is Equatable")
    func isEquatable() {
        #expect(Kernel.Error.notFound == Kernel.Error.notFound)
        #expect(Kernel.Error.notFound != Kernel.Error.permissionDenied)
    }

    @Test("platform error stores code and message")
    func platformError() {
        let error = Kernel.Error.platform(code: 42, message: "test message")
        if case .platform(let code, let message) = error {
            #expect(code == 42)
            #expect(message == "test message")
        } else {
            Issue.record("Expected platform error case")
        }
    }

    @Test("all semantic cases are distinct")
    func semanticCasesDistinct() {
        let cases: [Kernel.Error] = [
            .notFound,
            .permissionDenied,
            .alreadyExists,
            .isDirectory,
            .notDirectory,
            .notEmpty,
            .noSpace,
            .tooManyOpenFiles,
            .invalidDescriptor,
            .interrupted,
            .wouldBlock,
            .brokenPipe,
            .connectionReset,
            .deadlock,
            .noLocksAvailable,
            .invalidAddress,
            .outOfMemory,
        ]

        for (i, a) in cases.enumerated() {
            for (j, b) in cases.enumerated() {
                if i != j {
                    #expect(a != b, "Cases at index \(i) and \(j) should be different")
                }
            }
        }
    }
}

// MARK: - Edge Cases

extension Kernel.Error.Test.EdgeCase {
    @Test("description is non-empty for all cases")
    func descriptionNonEmpty() {
        let cases: [Kernel.Error] = [
            .notFound,
            .permissionDenied,
            .alreadyExists,
            .isDirectory,
            .notDirectory,
            .notEmpty,
            .noSpace,
            .tooManyOpenFiles,
            .invalidDescriptor,
            .interrupted,
            .wouldBlock,
            .brokenPipe,
            .connectionReset,
            .deadlock,
            .noLocksAvailable,
            .invalidAddress,
            .outOfMemory,
            .platform(code: 0, message: ""),
        ]

        for error in cases {
            #expect(!error.description.isEmpty, "\(error) should have non-empty description")
        }
    }

    @Test("platform error with empty message")
    func platformEmptyMessage() {
        let error = Kernel.Error.platform(code: -1, message: "")
        #expect(error.description.contains("-1"))
    }
}

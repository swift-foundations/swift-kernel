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

// MARK: - Kernel.Failure Tests

extension Kernel.Failure {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension Kernel.Failure.Test.Unit {
    @Test func `io case exists and wraps domain error`() {
        let ioError = Kernel.IO.Error.broken
        let failure = Kernel.Failure.io(ioError)

        if case .io(let wrapped) = failure {
            #expect(wrapped == ioError)
        } else {
            Issue.record("Expected .io case")
        }
    }

    @Test func `handle case exists and wraps domain error`() {
        let handleError = Kernel.Descriptor.Validity.Error.invalid
        let failure = Kernel.Failure.handle(handleError)

        if case .handle(let wrapped) = failure {
            #expect(wrapped == handleError)
        } else {
            Issue.record("Expected .handle case")
        }
    }

    @Test func `blocking case exists and wraps domain error`() {
        let blockingError = Kernel.IO.Blocking.Error.wouldBlock
        let failure = Kernel.Failure.blocking(blockingError)

        if case .blocking(let wrapped) = failure {
            #expect(wrapped == blockingError)
        } else {
            Issue.record("Expected .blocking case")
        }
    }

    @Test func `platform case exists and wraps kernel error`() {
        let kernelError = Kernel.Error(code: .POSIX.EPERM)
        let failure = Kernel.Failure.platform(kernelError)

        if case .platform(let wrapped) = failure {
            #expect(wrapped == kernelError)
        } else {
            Issue.record("Expected .platform case")
        }
    }

    #if !os(Windows)
    @Test func `signal case exists on non-Windows`() {
        let signalError = Kernel.Signal.Error.interrupted
        let failure = Kernel.Failure.signal(signalError)

        if case .signal(let wrapped) = failure {
            #expect(wrapped == signalError)
        } else {
            Issue.record("Expected .signal case")
        }
    }
    #endif

    @Test func `equatable conformance works`() {
        let a = Kernel.Failure.io(.broken)
        let b = Kernel.Failure.io(.broken)
        let c = Kernel.Failure.blocking(.wouldBlock)

        #expect(a == b)
        #expect(a != c)
    }

    @Test func `description produces non-empty string`() {
        let cases: [Kernel.Failure] = [
            .io(.broken),
            .handle(.invalid),
            .blocking(.wouldBlock),
            .platform(Kernel.Error(code: .POSIX.EPERM)),
        ]

        for failure in cases {
            let desc: Swift.String = failure.description
            #expect(!desc.isEmpty)
        }
    }

    @Test func `description prefixes with domain name`() {
        let ioFailure = Kernel.Failure.io(.broken)
        let desc: Swift.String = ioFailure.description
        #expect(desc.hasPrefix("io:"))

        let handleFailure = Kernel.Failure.handle(.invalid)
        let handleDesc: Swift.String = handleFailure.description
        #expect(handleDesc.hasPrefix("handle:"))

        let blockingFailure = Kernel.Failure.blocking(.wouldBlock)
        let blockingDesc: Swift.String = blockingFailure.description
        #expect(blockingDesc.hasPrefix("blocking:"))
    }

    @Test func `failable init returns nil for unrecognized code`() {
        // Error code 0 is not a real error on any platform
        let result = Kernel.Failure(.posix(0))
        #expect(result == nil)
    }
}

// MARK: - Kernel.Process.ID CustomStringConvertible Tests

extension Kernel.Process.ID {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension Kernel.Process.ID.Test.Unit {
    @Test func `description formats as raw value`() {
        let pid = Kernel.Process.ID(rawValue: 42)
        let desc: Swift.String = pid.description
        #expect(desc == "42")
    }

    @Test func `description formats zero correctly`() {
        let pid = Kernel.Process.ID(rawValue: 0)
        let desc: Swift.String = pid.description
        #expect(desc == "0")
    }

    @Test func `description formats init process correctly`() {
        #if !os(Windows)
        let pid = Kernel.Process.ID.`init`
        let desc: Swift.String = pid.description
        #expect(desc == "1")
        #endif
    }

    @Test func `description formats large value correctly`() {
        let pid = Kernel.Process.ID(rawValue: 32767)
        let desc: Swift.String = pid.description
        #expect(desc == "32767")
    }
}

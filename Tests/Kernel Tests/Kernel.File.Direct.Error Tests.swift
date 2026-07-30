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
import Kernel_Test_Support
import Tagged_Primitives_Standard_Library_Integration
// Tests use Apple native Testing framework
import Testing

extension Kernel.File.Direct.Error {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit Tests

extension Kernel.File.Direct.Error.Test.Unit {
    @Test
    func `notSupported case exists`() {
        let error = Kernel.File.Direct.Error.notSupported
        if case .notSupported = error {
            // Expected
        } else {
            Issue.record("Expected .notSupported case")
        }
    }

    @Test
    func `misalignedBuffer case exists`() {
        let error = Kernel.File.Direct.Error.misalignedBuffer(address: 123, required: .`4096`)
        if case .misalignedBuffer = error {
            // Expected
        } else {
            Issue.record("Expected .misalignedBuffer case")
        }
    }

    @Test
    func `misalignedOffset case exists`() {
        let error = Kernel.File.Direct.Error.misalignedOffset(offset: 100, required: .`4096`)
        if case .misalignedOffset = error {
            // Expected
        } else {
            Issue.record("Expected .misalignedOffset case")
        }
    }

    @Test
    func `invalidLength case exists`() {
        let error = Kernel.File.Direct.Error.invalidLength(length: 1000, requiredMultiple: .`4096`)
        if case .invalidLength = error {
            // Expected
        } else {
            Issue.record("Expected .invalidLength case")
        }
    }

    @Test
    func `modeChange case exists`() {
        let error = Kernel.File.Direct.Error.modeChange
        if case .modeChange = error {
            // Expected
        } else {
            Issue.record("Expected .modeChange case")
        }
    }

    @Test
    func `invalidHandle case exists`() {
        let error = Kernel.File.Direct.Error.invalidHandle
        if case .invalidHandle = error {
            // Expected
        } else {
            Issue.record("Expected .invalidHandle case")
        }
    }

    @Test
    func `platform case exists`() {
        let error = Kernel.File.Direct.Error.platform(code: .posix(1), operation: .open)
        if case .platform = error {
            // Expected
        } else {
            Issue.record("Expected .platform case")
        }
    }
}

// MARK: - Description Tests

extension Kernel.File.Direct.Error.Test.Unit {
    @Test
    func `notSupported description`() {
        let error = Kernel.File.Direct.Error.notSupported
        #expect(error.description == "Direct I/O not supported")
    }

    @Test
    func `modeChange description`() {
        let error = Kernel.File.Direct.Error.modeChange
        #expect(error.description == "Failed to change cache mode")
    }

    @Test
    func `invalidHandle description`() {
        let error = Kernel.File.Direct.Error.invalidHandle
        #expect(error.description == "Invalid file handle")
    }

    @Test
    func `misalignedBuffer description includes address`() {
        let error = Kernel.File.Direct.Error.misalignedBuffer(address: 123, required: .`4096`)
        #expect(error.description.contains("Buffer address"))
        #expect(error.description.contains("4096"))
    }

    @Test
    func `misalignedOffset description includes offset`() {
        let error = Kernel.File.Direct.Error.misalignedOffset(offset: 100, required: .`4096`)
        #expect(error.description.contains("File offset"))
        #expect(error.description.contains("100"))
    }

    @Test
    func `invalidLength description includes length`() {
        let error = Kernel.File.Direct.Error.invalidLength(length: 1000, requiredMultiple: .`4096`)
        #expect(error.description.contains("Length"))
        #expect(error.description.contains("1000"))
    }
}

// MARK: - Conformance Tests

extension Kernel.File.Direct.Error.Test.Unit {
    @Test
    func `Error conforms to Swift.Error`() {
        let error: any Swift.Error = Kernel.File.Direct.Error.notSupported
        #expect(error is Kernel.File.Direct.Error)
    }

    @Test
    func `Error is Sendable`() {
        let error: any Sendable = Kernel.File.Direct.Error.notSupported
        #expect(error is Kernel.File.Direct.Error)
    }

    @Test
    func `Error is Equatable`() {
        let a = Kernel.File.Direct.Error.notSupported
        let b = Kernel.File.Direct.Error.notSupported
        let c = Kernel.File.Direct.Error.modeChange
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - Nested Types

extension Kernel.File.Direct.Error.Test.Unit {
    @Test
    func `Operation type exists`() {
        let _: Kernel.File.Direct.Error.Operation.Type = Kernel.File.Direct.Error.Operation.self
    }

    @Test
    func `Syscall type exists`() {
        let _: Kernel.File.Direct.Error.Syscall.Type = Kernel.File.Direct.Error.Syscall.self
    }
}

// MARK: - Edge Cases

extension Kernel.File.Direct.Error.Test.EdgeCase {
    @Test
    func `all simple cases are distinct`() {
        let cases: [Kernel.File.Direct.Error] = [
            .notSupported,
            .modeChange,
            .invalidHandle,
        ]

        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j])
            }
        }
    }

    @Test
    func `misalignedBuffer errors with different addresses are distinct`() {
        let error1 = Kernel.File.Direct.Error.misalignedBuffer(address: 100, required: .`4096`)
        let error2 = Kernel.File.Direct.Error.misalignedBuffer(address: 200, required: .`4096`)
        #expect(error1 != error2)
    }

    @Test
    func `all descriptions are non-empty`() {
        let cases: [Kernel.File.Direct.Error] = [
            .notSupported,
            .misalignedBuffer(address: 123, required: .`4096`),
            .misalignedOffset(offset: 100, required: .`4096`),
            .invalidLength(length: 1000, requiredMultiple: .`4096`),
            .modeChange,
            .invalidHandle,
            .platform(code: .posix(1), operation: .open),
        ]

        for error in cases {
            #expect(!error.description.isEmpty)
        }
    }
}

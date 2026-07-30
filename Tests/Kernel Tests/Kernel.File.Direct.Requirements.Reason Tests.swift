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
import Tagged_Primitives_Standard_Library_Integration
// Tests use Apple native Testing framework
import Testing

extension Kernel.File.Direct.Requirements.Reason {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit Tests

extension Kernel.File.Direct.Requirements.Reason.Test.Unit {
    @Test
    func `platformUnsupported case exists`() {
        let reason = Kernel.File.Direct.Requirements.Reason.platformUnsupported
        if case .platformUnsupported = reason {
            // Expected
        } else {
            Issue.record("Expected .platformUnsupported case")
        }
    }

    @Test
    func `sectorSizeUndetermined case exists`() {
        let reason = Kernel.File.Direct.Requirements.Reason.sectorSizeUndetermined
        if case .sectorSizeUndetermined = reason {
            // Expected
        } else {
            Issue.record("Expected .sectorSizeUndetermined case")
        }
    }

    @Test
    func `filesystemUnsupported case exists`() {
        let reason = Kernel.File.Direct.Requirements.Reason.filesystemUnsupported
        if case .filesystemUnsupported = reason {
            // Expected
        } else {
            Issue.record("Expected .filesystemUnsupported case")
        }
    }

    @Test
    func `invalidHandle case exists`() {
        let reason = Kernel.File.Direct.Requirements.Reason.invalidHandle
        if case .invalidHandle = reason {
            // Expected
        } else {
            Issue.record("Expected .invalidHandle case")
        }
    }
}

// MARK: - Description Tests

extension Kernel.File.Direct.Requirements.Reason.Test.Unit {
    @Test
    func `platformUnsupported description`() {
        let reason = Kernel.File.Direct.Requirements.Reason.platformUnsupported
        #expect(reason.description == "Platform does not support strict Direct I/O")
    }

    @Test
    func `sectorSizeUndetermined description`() {
        let reason = Kernel.File.Direct.Requirements.Reason.sectorSizeUndetermined
        #expect(reason.description == "Could not determine sector size")
    }

    @Test
    func `filesystemUnsupported description`() {
        let reason = Kernel.File.Direct.Requirements.Reason.filesystemUnsupported
        #expect(reason.description == "Filesystem does not support Direct I/O")
    }

    @Test
    func `invalidHandle description`() {
        let reason = Kernel.File.Direct.Requirements.Reason.invalidHandle
        #expect(reason.description == "Invalid file handle")
    }
}

// MARK: - Conformance Tests

extension Kernel.File.Direct.Requirements.Reason.Test.Unit {
    @Test
    func `Reason is Sendable`() {
        let reason: any Sendable = Kernel.File.Direct.Requirements.Reason.platformUnsupported
        #expect(reason is Kernel.File.Direct.Requirements.Reason)
    }

    @Test
    func `Reason is Equatable`() {
        let a = Kernel.File.Direct.Requirements.Reason.platformUnsupported
        let b = Kernel.File.Direct.Requirements.Reason.platformUnsupported
        let c = Kernel.File.Direct.Requirements.Reason.sectorSizeUndetermined
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `Reason is CustomStringConvertible`() {
        let reason: any CustomStringConvertible = Kernel.File.Direct.Requirements.Reason.platformUnsupported
        #expect(!reason.description.isEmpty)
    }
}

// MARK: - Edge Cases

extension Kernel.File.Direct.Requirements.Reason.Test.EdgeCase {
    @Test
    func `all reasons are distinct`() {
        let reasons: [Kernel.File.Direct.Requirements.Reason] = [
            .platformUnsupported,
            .sectorSizeUndetermined,
            .filesystemUnsupported,
            .invalidHandle,
        ]

        for i in 0..<reasons.count {
            for j in (i + 1)..<reasons.count {
                #expect(reasons[i] != reasons[j])
            }
        }
    }

    @Test
    func `all descriptions are distinct`() {
        let descriptions = [
            Kernel.File.Direct.Requirements.Reason.platformUnsupported.description,
            Kernel.File.Direct.Requirements.Reason.sectorSizeUndetermined.description,
            Kernel.File.Direct.Requirements.Reason.filesystemUnsupported.description,
            Kernel.File.Direct.Requirements.Reason.invalidHandle.description,
        ]

        let uniqueDescriptions = Set(descriptions)
        #expect(uniqueDescriptions.count == descriptions.count)
    }

    @Test
    func `all descriptions are non-empty`() {
        let reasons: [Kernel.File.Direct.Requirements.Reason] = [
            .platformUnsupported,
            .sectorSizeUndetermined,
            .filesystemUnsupported,
            .invalidHandle,
        ]

        for reason in reasons {
            #expect(!reason.description.isEmpty)
        }
    }
}

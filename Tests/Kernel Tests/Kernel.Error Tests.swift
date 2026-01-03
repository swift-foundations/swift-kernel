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

extension Kernel.Error {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Error.Test.Unit {
    @Test("error conforms to Swift.Error")
    func conformsToError() {
        let error: any Swift.Error = Kernel.Error.path(.notFound)
        #expect(error is Kernel.Error)
    }

    @Test("error is Sendable")
    func isSendable() {
        let error: any Sendable = Kernel.Error.path(.notFound)
        #expect(error is Kernel.Error)
    }

    @Test("error is Equatable")
    func isEquatable() {
        #expect(Kernel.Error.path(.notFound) == Kernel.Error.path(.notFound))
        #expect(Kernel.Error.path(.notFound) != Kernel.Error.resource(.permission(.denied)))
    }

    @Test("platform error stores code")
    func platformError() {
        let error = Kernel.Error.platform(code: 42)
        if case .platform(let code) = error {
            #expect(code == 42)
        } else {
            Issue.record("Expected platform error case")
        }
    }

    @Test("all error categories are distinct")
    func errorCategoriesDistinct() {
        let categories: [Kernel.Error] = [
            .path(.notFound),
            .descriptor(.invalid),
            .io(.broken),
            .lock(.deadlock),
            .memory(.address),
            .resource(.permission(.denied)),
            .platform(code: 0),
        ]

        for (i, a) in categories.enumerated() {
            for (j, b) in categories.enumerated() {
                if i != j {
                    #expect(a != b, "Categories at index \(i) and \(j) should be different")
                }
            }
        }
    }

    @Test("Path error cases are distinct")
    func pathCasesDistinct() {
        let cases: [Kernel.Error.Path] = [.notFound, .exists, .isDirectory, .notDirectory, .notEmpty, .crossDevice]
        for (i, a) in cases.enumerated() {
            for (j, b) in cases.enumerated() {
                if i != j {
                    #expect(a != b)
                }
            }
        }
    }

    @Test("Descriptor error cases are distinct")
    func descriptorCasesDistinct() {
        #expect(Kernel.Error.Descriptor.invalid != Kernel.Error.Descriptor.limit(.process))
        #expect(Kernel.Error.Descriptor.limit(.process) != Kernel.Error.Descriptor.limit(.system))
    }

    @Test("IO error cases are distinct")
    func ioCasesDistinct() {
        let cases: [Kernel.Error.IO] = [.broken, .reset, .device(.unsupported), .device(.unavailable), .seek]
        for (i, a) in cases.enumerated() {
            for (j, b) in cases.enumerated() {
                if i != j {
                    #expect(a != b)
                }
            }
        }
    }

    @Test("Lock error cases are distinct")
    func lockCasesDistinct() {
        #expect(Kernel.Error.Lock.deadlock != Kernel.Error.Lock.unavailable)
    }

    @Test("Memory error cases are distinct")
    func memoryCasesDistinct() {
        #expect(Kernel.Error.Memory.address != Kernel.Error.Memory.exhausted)
    }

    @Test("Resource error cases are distinct")
    func resourceCasesDistinct() {
        let cases: [Kernel.Error.Resource] = [.permission(.denied), .permission(.notPermitted), .space, .interrupted, .blocked, .unsupported]
        for (i, a) in cases.enumerated() {
            for (j, b) in cases.enumerated() {
                if i != j {
                    #expect(a != b)
                }
            }
        }
    }
}

// MARK: - Edge Cases

extension Kernel.Error.Test.EdgeCase {
    @Test("description is non-empty for all error categories")
    func descriptionNonEmpty() {
        let cases: [Kernel.Error] = [
            .path(.notFound),
            .path(.exists),
            .path(.isDirectory),
            .path(.notDirectory),
            .path(.notEmpty),
            .path(.crossDevice),
            .descriptor(.invalid),
            .descriptor(.limit(.process)),
            .descriptor(.limit(.system)),
            .io(.broken),
            .io(.reset),
            .io(.device(.unsupported)),
            .io(.device(.unavailable)),
            .io(.seek),
            .lock(.deadlock),
            .lock(.unavailable),
            .memory(.address),
            .memory(.exhausted),
            .resource(.permission(.denied)),
            .resource(.permission(.notPermitted)),
            .resource(.space),
            .resource(.interrupted),
            .resource(.blocked),
            .resource(.unsupported),
            .platform(code: 0),
        ]

        for error in cases {
            #expect(!error.description.isEmpty, "\(error) should have non-empty description")
        }
    }

    @Test("platform error description contains code")
    func platformErrorDescription() {
        let error = Kernel.Error.platform(code: -1)
        #expect(error.description.contains("-1"))
    }
}

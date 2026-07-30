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

@_spi(Syscall) import Error_Primitives
import Kernel_Test_Support
@_spi(Syscall) import Path_Primitives
import Tagged_Primitives_Standard_Library_Integration
// Tests use Apple native Testing framework
import Testing

@testable import Kernel

extension Kernel.Copy.Error {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit Tests

extension Kernel.Copy.Error.Test.Unit {
    @Test
    func `invalidDescriptor case exists`() {
        let error = Kernel.Copy.Error.invalidDescriptor
        if case .invalidDescriptor = error {
            // Expected
        } else {
            Issue.record("Expected .invalidDescriptor case")
        }
    }

    @Test
    func `crossDevice case exists`() {
        let error = Kernel.Copy.Error.crossDevice
        if case .crossDevice = error {
            // Expected
        } else {
            Issue.record("Expected .crossDevice case")
        }
    }

    @Test
    func `unsupported case exists`() {
        let error = Kernel.Copy.Error.unsupported
        if case .unsupported = error {
            // Expected
        } else {
            Issue.record("Expected .unsupported case")
        }
    }

    @Test
    func `noSpace case exists`() {
        let error = Kernel.Copy.Error.noSpace
        if case .noSpace = error {
            // Expected
        } else {
            Issue.record("Expected .noSpace case")
        }
    }

    @Test
    func `io case exists`() {
        let error = Kernel.Copy.Error.io
        if case .io = error {
            // Expected
        } else {
            Issue.record("Expected .io case")
        }
    }

    @Test
    func `permissionDenied case exists`() {
        let error = Kernel.Copy.Error.permissionDenied
        if case .permissionDenied = error {
            // Expected
        } else {
            Issue.record("Expected .permissionDenied case")
        }
    }
}

// MARK: - Description Tests

extension Kernel.Copy.Error.Test.Unit {
    @Test
    func `invalidDescriptor description`() {
        #expect(Kernel.Copy.Error.invalidDescriptor.description == "invalid file descriptor")
    }

    @Test
    func `crossDevice description`() {
        #expect(Kernel.Copy.Error.crossDevice.description == "cross-device copy not supported")
    }

    @Test
    func `unsupported description`() {
        #expect(Kernel.Copy.Error.unsupported.description == "operation not supported")
    }

    @Test
    func `noSpace description`() {
        #expect(Kernel.Copy.Error.noSpace.description == "no space left on device")
    }

    @Test
    func `io description`() {
        #expect(Kernel.Copy.Error.io.description == "I/O error")
    }

    @Test
    func `permissionDenied description`() {
        #expect(Kernel.Copy.Error.permissionDenied.description == "permission denied")
    }
}

// MARK: - Conformance Tests

extension Kernel.Copy.Error.Test.Unit {
    @Test
    func `Error conforms to Swift.Error`() {
        let error: any Swift.Error = Kernel.Copy.Error.invalidDescriptor
        #expect(error is Kernel.Copy.Error)
    }

    @Test
    func `Error is Sendable`() {
        let error: any Sendable = Kernel.Copy.Error.invalidDescriptor
        #expect(error is Kernel.Copy.Error)
    }

    @Test
    func `Error is Equatable`() {
        let a = Kernel.Copy.Error.invalidDescriptor
        let b = Kernel.Copy.Error.invalidDescriptor
        let c = Kernel.Copy.Error.crossDevice
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `Error is Hashable`() {
        var set = Set<Kernel.Copy.Error>()
        set.insert(.invalidDescriptor)
        set.insert(.crossDevice)
        set.insert(.invalidDescriptor)  // duplicate
        #expect(set.count == 2)
    }
}

// MARK: - Edge Cases

extension Kernel.Copy.Error.Test.EdgeCase {
    @Test
    func `all cases are distinct`() {
        let cases: [Kernel.Copy.Error] = [
            .invalidDescriptor,
            .crossDevice,
            .unsupported,
            .noSpace,
            .io,
            .permissionDenied,
        ]

        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j])
            }
        }
    }
}

// MARK: - POSIX Error Mapping Tests
//
// Kernel.Copy.Error(posixErrno:) is POSIX-only (Kernel.Copy.Error+posixErrno.swift
// is gated the same way); this whole section is gated to match.

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.Copy.Error.Test.Unit {
        @Test
        func `EBADF maps to invalidDescriptor`() {
            let error = Kernel.Copy.Error(posixErrno: EBADF)
            #expect(error == .invalidDescriptor)
        }

        @Test
        func `EXDEV maps to crossDevice`() {
            let error = Kernel.Copy.Error(posixErrno: EXDEV)
            #expect(error == .crossDevice)
        }

        @Test
        func `EINVAL maps to unsupported`() {
            let error = Kernel.Copy.Error(posixErrno: EINVAL)
            #expect(error == .unsupported)
        }

        @Test
        func `ENOTSUP maps to unsupported`() {
            let error = Kernel.Copy.Error(posixErrno: ENOTSUP)
            #expect(error == .unsupported)
        }

        @Test
        func `EOPNOTSUPP maps to unsupported`() {
            let error = Kernel.Copy.Error(posixErrno: EOPNOTSUPP)
            #expect(error == .unsupported)
        }

        @Test
        func `ENOSPC maps to noSpace`() {
            let error = Kernel.Copy.Error(posixErrno: ENOSPC)
            #expect(error == .noSpace)
        }

        @Test
        func `EIO maps to io`() {
            let error = Kernel.Copy.Error(posixErrno: EIO)
            #expect(error == .io)
        }

        @Test
        func `EACCES maps to permissionDenied`() {
            let error = Kernel.Copy.Error(posixErrno: EACCES)
            #expect(error == .permissionDenied)
        }

        @Test
        func `EPERM maps to permissionDenied`() {
            let error = Kernel.Copy.Error(posixErrno: EPERM)
            #expect(error == .permissionDenied)
        }

        @Test
        func `unknown error maps to unsupported`() {
            // Use an unlikely error code
            let error = Kernel.Copy.Error(posixErrno: 999)
            #expect(error == .unsupported)
        }
    }

#endif

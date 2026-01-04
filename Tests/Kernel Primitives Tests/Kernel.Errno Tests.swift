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

import StandardsTestSupport
import Testing

@testable import Kernel_Primitives

extension Kernel.Errno {
    #TestSuites
}

// MARK: - Errno Tests

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.Errno.Test.Unit {
        @Test("noEntry equals ENOENT")
        func noEntryEqualsENOENT() {
            #expect(Kernel.Errno.noEntry == ENOENT)
        }

        @Test("accessDenied equals EACCES")
        func accessDeniedEqualsEACCES() {
            #expect(Kernel.Errno.accessDenied == EACCES)
        }

        @Test("notPermitted equals EPERM")
        func notPermittedEqualsEPERM() {
            #expect(Kernel.Errno.notPermitted == EPERM)
        }

        @Test("exists equals EEXIST")
        func existsEqualsEEXIST() {
            #expect(Kernel.Errno.exists == EEXIST)
        }

        @Test("isDirectory equals EISDIR")
        func isDirectoryEqualsEISDIR() {
            #expect(Kernel.Errno.isDirectory == EISDIR)
        }

        @Test("processLimit equals EMFILE")
        func processLimitEqualsEMFILE() {
            #expect(Kernel.Errno.processLimit == EMFILE)
        }

        @Test("systemLimit equals ENFILE")
        func systemLimitEqualsENFILE() {
            #expect(Kernel.Errno.systemLimit == ENFILE)
        }

        @Test("invalid equals EINVAL")
        func invalidEqualsEINVAL() {
            #expect(Kernel.Errno.invalid == EINVAL)
        }

        @Test("interrupted equals EINTR")
        func interruptedEqualsEINTR() {
            #expect(Kernel.Errno.interrupted == EINTR)
        }

        @Test("wouldBlock equals EAGAIN")
        func wouldBlockEqualsEAGAIN() {
            #expect(Kernel.Errno.wouldBlock == EAGAIN)
        }

        @Test("noDevice equals ENODEV")
        func noDeviceEqualsENODEV() {
            #expect(Kernel.Errno.noDevice == ENODEV)
        }

        @Test("notDirectory equals ENOTDIR")
        func notDirectoryEqualsENOTDIR() {
            #expect(Kernel.Errno.notDirectory == ENOTDIR)
        }

        @Test("readOnlyFilesystem equals EROFS")
        func readOnlyFilesystemEqualsEROFS() {
            #expect(Kernel.Errno.readOnlyFilesystem == EROFS)
        }

        @Test("noSpace equals ENOSPC")
        func noSpaceEqualsENOSPC() {
            #expect(Kernel.Errno.noSpace == ENOSPC)
        }

        @Test("badDescriptor equals EBADF")
        func badDescriptorEqualsEBADF() {
            #expect(Kernel.Errno.badDescriptor == EBADF)
        }
    }

    extension Kernel.Errno.Test.Unit {
        @Test("all errno values are distinct")
        func allValuesDistinct() {
            let values: [Int32] = [
                Kernel.Errno.noEntry,
                Kernel.Errno.accessDenied,
                Kernel.Errno.notPermitted,
                Kernel.Errno.exists,
                Kernel.Errno.isDirectory,
                Kernel.Errno.processLimit,
                Kernel.Errno.systemLimit,
                Kernel.Errno.invalid,
                Kernel.Errno.interrupted,
                Kernel.Errno.noDevice,
                Kernel.Errno.notDirectory,
                Kernel.Errno.readOnlyFilesystem,
                Kernel.Errno.noSpace,
                Kernel.Errno.badDescriptor,
            ]
            let uniqueValues = Set(values)
            #expect(uniqueValues.count == values.count, "All errno values should be distinct")
        }

        @Test("all errno values are positive")
        func allValuesPositive() {
            #expect(Kernel.Errno.noEntry > 0)
            #expect(Kernel.Errno.accessDenied > 0)
            #expect(Kernel.Errno.notPermitted > 0)
            #expect(Kernel.Errno.exists > 0)
            #expect(Kernel.Errno.invalid > 0)
            #expect(Kernel.Errno.interrupted > 0)
            #expect(Kernel.Errno.badDescriptor > 0)
        }
    }

#endif

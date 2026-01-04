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

@testable import Kernel_Primitives

// Kernel.Error.Mapping.swift contains extension initializers for error mapping.
// These tests verify the error mapping functionality without a type to extend.

#if !os(Windows)
import SystemPackage

// MARK: - Path.Resolution.Error Mapping Tests

@Suite("Path.Resolution.Error Mapping")
struct PathResolutionErrorMappingTests {
    @Test("notFound from ENOENT")
    func notFoundMapping() {
        let error = Kernel.Path.Resolution.Error(errno: .noSuchFileOrDirectory)
        #expect(error == .notFound)
    }

    @Test("exists from EEXIST")
    func existsMapping() {
        let error = Kernel.Path.Resolution.Error(errno: .fileExists)
        #expect(error == .exists)
    }

    @Test("isDirectory from EISDIR")
    func isDirectoryMapping() {
        let error = Kernel.Path.Resolution.Error(errno: .isDirectory)
        #expect(error == .isDirectory)
    }

    @Test("notDirectory from ENOTDIR")
    func notDirectoryMapping() {
        let error = Kernel.Path.Resolution.Error(errno: .notDirectory)
        #expect(error == .notDirectory)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.Path.Resolution.Error(errno: .interrupted)
        #expect(error == nil)
    }
}

// MARK: - Permission.Error Mapping Tests

@Suite("Permission.Error Mapping")
struct PermissionErrorMappingTests {
    @Test("denied from EACCES")
    func deniedMapping() {
        let error = Kernel.Permission.Error(errno: .permissionDenied)
        #expect(error == .denied)
    }

    @Test("notPermitted from EPERM")
    func notPermittedMapping() {
        let error = Kernel.Permission.Error(errno: .notPermitted)
        #expect(error == .notPermitted)
    }

    @Test("readOnlyFilesystem from EROFS")
    func readOnlyFilesystemMapping() {
        let error = Kernel.Permission.Error(errno: .readOnlyFileSystem)
        #expect(error == .readOnlyFilesystem)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.Permission.Error(errno: .interrupted)
        #expect(error == nil)
    }
}

// MARK: - Descriptor.Validity.Error Mapping Tests

@Suite("Descriptor.Validity.Error Mapping")
struct DescriptorValidityErrorMappingTests {
    @Test("invalid from EBADF")
    func invalidMapping() {
        let error = Kernel.Descriptor.Validity.Error(errno: .badFileDescriptor)
        #expect(error == .invalid)
    }

    @Test("limit process from EMFILE")
    func processLimitMapping() {
        let error = Kernel.Descriptor.Validity.Error(errno: .tooManyOpenFiles)
        #expect(error == .limit(.process))
    }

    @Test("limit system from ENFILE")
    func systemLimitMapping() {
        let error = Kernel.Descriptor.Validity.Error(errno: .tooManyOpenFilesInSystem)
        #expect(error == .limit(.system))
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.Descriptor.Validity.Error(errno: .interrupted)
        #expect(error == nil)
    }
}

// MARK: - Signal.Error Mapping Tests

@Suite("Signal.Error Mapping")
struct SignalErrorMappingTests {
    @Test("interrupted from EINTR")
    func interruptedMapping() {
        let error = Kernel.Signal.Error(errno: .interrupted)
        #expect(error == .interrupted)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.Signal.Error(errno: .permissionDenied)
        #expect(error == nil)
    }
}

// MARK: - IO.Blocking.Error Mapping Tests

@Suite("IO.Blocking.Error Mapping")
struct IOBlockingErrorMappingTests {
    @Test("wouldBlock from EAGAIN")
    func wouldBlockMapping() {
        let error = Kernel.IO.Blocking.Error(errno: .wouldBlock)
        #expect(error == .wouldBlock)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.IO.Blocking.Error(errno: .permissionDenied)
        #expect(error == nil)
    }
}

// MARK: - Storage.Error Mapping Tests

@Suite("Storage.Error Mapping")
struct StorageErrorMappingTests {
    @Test("exhausted from ENOSPC")
    func exhaustedMapping() {
        let error = Kernel.Storage.Error(errno: .noSpace)
        #expect(error == .exhausted)
    }

    @Test("quota from EDQUOT")
    func quotaMapping() {
        let error = Kernel.Storage.Error(errno: .diskQuotaExceeded)
        #expect(error == .quota)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.Storage.Error(errno: .interrupted)
        #expect(error == nil)
    }
}

// MARK: - Memory.Error Mapping Tests

@Suite("Memory.Error Mapping")
struct MemoryErrorMappingTests {
    @Test("fault from EFAULT")
    func faultMapping() {
        let error = Kernel.Memory.Error(errno: .badAddress)
        #expect(error == .fault)
    }

    @Test("exhausted from ENOMEM")
    func exhaustedMapping() {
        let error = Kernel.Memory.Error(errno: .noMemory)
        #expect(error == .exhausted)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.Memory.Error(errno: .interrupted)
        #expect(error == nil)
    }
}

// MARK: - IO.Error Mapping Tests

@Suite("IO.Error Mapping")
struct IOErrorMappingTests {
    @Test("hardware from EIO")
    func hardwareMapping() {
        let error = Kernel.IO.Error(errno: .ioError)
        #expect(error == .hardware)
    }

    @Test("broken from EPIPE")
    func brokenMapping() {
        let error = Kernel.IO.Error(errno: .brokenPipe)
        #expect(error == .broken)
    }

    @Test("reset from ECONNRESET")
    func resetMapping() {
        let error = Kernel.IO.Error(errno: .connectionReset)
        #expect(error == .reset)
    }

    @Test("returns nil for unmapped errno")
    func unmappedReturnsNil() {
        let error = Kernel.IO.Error(errno: .interrupted)
        #expect(error == nil)
    }
}

// MARK: - Errno.Unmapped.Error Tests

@Suite("Errno.Unmapped.Error Mapping")
struct ErrnoUnmappedErrorMappingTests {
    @Test("creates platform error from errno")
    func fromErrno() {
        let error = Kernel.Errno.Unmapped.Error(errno: .interrupted)
        if case .unmapped(let code, _) = error {
            if case .posix(let value) = code {
                #expect(value == Errno.interrupted.rawValue)
            } else {
                Issue.record("Expected .posix code")
            }
        } else {
            Issue.record("Expected .unmapped case")
        }
    }
}

#endif

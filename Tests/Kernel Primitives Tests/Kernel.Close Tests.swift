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
import StandardsTestSupport
import Testing

@testable import Kernel_Primitives

import SystemPackage

extension Kernel.Close {
    #TestSuites
}

// MARK: - Close Tests

#if !os(Windows)

    extension Kernel.Close.Test.Unit {
        @Test("close succeeds on valid descriptor")
        func closeSucceedsOnValidDescriptor() throws {
            let (path, fd) = try KernelIOTest.createTempFile(prefix: "close-test")
            defer { try? Kernel.Unlink.unlink(path) }

            // Close should succeed
            try Kernel.Close.close(fd)

            // Descriptor should now be invalid - further operations should fail
            // (We can't easily test this without trying to use it, which would be UB on POSIX)
        }

        @Test("close is idempotent in practice")
        func closeIdempotentBehavior() throws {
            // NOTE: POSIX says closing an already-closed fd is undefined behavior.
            // However, Kernel.Close checks isValid before calling the syscall.
            // This test verifies that the isValid check catches invalid descriptors.
            let invalidFd = Kernel.Descriptor(rawValue: -1)

            // Should throw because descriptor is invalid
            #expect(throws: Kernel.Close.Error.self) {
                try Kernel.Close.close(invalidFd)
            }
        }
    }

    // MARK: - Error Tests

    extension Kernel.Close.Test.EdgeCase {
        @Test("close throws on invalid descriptor")
        func closeThrowsOnInvalidDescriptor() {
            let invalidFd = Kernel.Descriptor(rawValue: -1)

            #expect(throws: Kernel.Close.Error.self) {
                try Kernel.Close.close(invalidFd)
            }
        }

        @Test("close with negative descriptor throws")
        func closeNegativeDescriptorThrows() {
            let negativeFd = Kernel.Descriptor(rawValue: -100)

            #expect(throws: Kernel.Close.Error.self) {
                try Kernel.Close.close(negativeFd)
            }
        }
    }

#endif

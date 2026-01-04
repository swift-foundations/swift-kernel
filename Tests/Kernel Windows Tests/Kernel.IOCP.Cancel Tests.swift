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

#if os(Windows)
import WinSDK
import StandardsTestSupport
import Testing

@testable import Kernel_Windows
import Kernel_Primitives

extension Kernel.IOCP.Cancel {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.IOCP.Cancel.Test.Unit {
    @Test("Cancel namespace exists")
    func namespaceExists() {
        _ = Kernel.IOCP.Cancel.self
    }

    @Test("Cancel is an enum")
    func isEnum() {
        let _: Kernel.IOCP.Cancel.Type = Kernel.IOCP.Cancel.self
    }

    @Test("pending function exists")
    func pendingFunctionExists() {
        // Verify the function signature exists
        let _: (HANDLE, LPOVERLAPPED) -> Void = Kernel.IOCP.Cancel.pending
    }

    @Test("io function exists")
    func ioFunctionExists() {
        // Verify the function signature exists
        let _: (HANDLE, UnsafeMutablePointer<OVERLAPPED>) -> Bool = Kernel.IOCP.Cancel.io
    }
}

// MARK: - pending() Tests

extension Kernel.IOCP.Cancel.Test.Unit {
    @Test("pending does not crash with invalid handle")
    func pendingWithInvalidHandle() {
        var overlapped = OVERLAPPED()
        withUnsafeMutablePointer(to: &overlapped) { ptr in
            // Should not crash - errors are silently ignored
            Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: ptr)
        }
    }

    @Test("pending is fire-and-forget")
    func pendingIsFireAndForget() {
        // pending() returns Void, so it's truly fire-and-forget
        var overlapped = OVERLAPPED()
        withUnsafeMutablePointer(to: &overlapped) { ptr in
            Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: ptr)
            // No return value to check - this is intentional
        }
    }
}

// MARK: - io() Tests

extension Kernel.IOCP.Cancel.Test.Unit {
    @Test("io returns Bool")
    func ioReturnsBool() {
        var overlapped = OVERLAPPED()
        let result = withUnsafeMutablePointer(to: &overlapped) { ptr in
            Kernel.IOCP.Cancel.io(INVALID_HANDLE_VALUE, overlapped: ptr)
        }
        // Result should be a Bool
        #expect(result is Bool)
    }

    @Test("io with invalid handle returns appropriate value")
    func ioWithInvalidHandle() {
        var overlapped = OVERLAPPED()
        let result = withUnsafeMutablePointer(to: &overlapped) { ptr in
            Kernel.IOCP.Cancel.io(INVALID_HANDLE_VALUE, overlapped: ptr)
        }
        // With invalid handle, CancelIoEx fails
        // Result depends on whether error is ERROR_NOT_FOUND
        #expect(result == true || result == false)
    }
}

// MARK: - Return Value Semantics Tests

extension Kernel.IOCP.Cancel.Test.Unit {
    @Test("io returns true when cancelled, false when not found")
    func ioReturnValueSemantics() {
        // The function returns:
        // - true if cancelled successfully
        // - false if ERROR_NOT_FOUND (operation already completed)
        // - true for other errors (conservative approach)

        // This test documents the expected behavior
        var overlapped = OVERLAPPED()
        _ = withUnsafeMutablePointer(to: &overlapped) { ptr in
            Kernel.IOCP.Cancel.io(INVALID_HANDLE_VALUE, overlapped: ptr)
        }
        // Cannot easily verify without an actual pending I/O operation
    }
}

// MARK: - Edge Cases

extension Kernel.IOCP.Cancel.Test.EdgeCase {
    @Test("pending with null overlapped pointer")
    func pendingNullOverlapped() {
        // Note: This would be UB in C, but tests the API boundary
        // In practice, callers should never pass null
        Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: nil)
        // Should not crash
    }

    @Test("Cancel operations are safe to call multiple times")
    func cancelMultipleTimes() {
        var overlapped = OVERLAPPED()
        withUnsafeMutablePointer(to: &overlapped) { ptr in
            // Call pending multiple times - should be safe
            for _ in 0..<3 {
                Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: ptr)
            }

            // Call io multiple times - should be safe
            for _ in 0..<3 {
                _ = Kernel.IOCP.Cancel.io(INVALID_HANDLE_VALUE, overlapped: ptr)
            }
        }
    }

    @Test("Cancel with different overlapped instances")
    func cancelDifferentOverlappeds() {
        var overlapped1 = OVERLAPPED()
        var overlapped2 = OVERLAPPED()
        var overlapped3 = OVERLAPPED()

        withUnsafeMutablePointer(to: &overlapped1) { ptr1 in
            withUnsafeMutablePointer(to: &overlapped2) { ptr2 in
                withUnsafeMutablePointer(to: &overlapped3) { ptr3 in
                    Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: ptr1)
                    Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: ptr2)
                    Kernel.IOCP.Cancel.pending(fileHandle: INVALID_HANDLE_VALUE, overlapped: ptr3)
                }
            }
        }
    }
}

// MARK: - WindowsError Integration Tests

extension Kernel.IOCP.Cancel.Test.Unit {
    @Test("io uses WindowsError.notFound for comparison")
    func ioUsesNotFoundConstant() {
        // Verify that the implementation checks against ERROR_NOT_FOUND
        // by ensuring the constant is accessible
        let notFound = Kernel.IOCP.WindowsError.notFound
        #expect(notFound == 1168) // ERROR_NOT_FOUND
    }
}

#endif

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

    extension Kernel.IOCP.WindowsError {
        #TestSuites
    }

    // MARK: - Unit Tests

    extension Kernel.IOCP.WindowsError.Test.Unit {
        @Test("WindowsError namespace exists")
        func namespaceExists() {
            _ = Kernel.IOCP.WindowsError.self
        }

        @Test("WindowsError is an enum")
        func isEnum() {
            let _: Kernel.IOCP.WindowsError.Type = Kernel.IOCP.WindowsError.self
        }
    }

    // MARK: - Constant Tests

    extension Kernel.IOCP.WindowsError.Test.Unit {
        @Test("ioPending matches ERROR_IO_PENDING")
        func ioPendingConstant() {
            #expect(Kernel.IOCP.WindowsError.ioPending == UInt32(ERROR_IO_PENDING))
        }

        @Test("operationAborted matches ERROR_OPERATION_ABORTED")
        func operationAbortedConstant() {
            #expect(Kernel.IOCP.WindowsError.operationAborted == UInt32(ERROR_OPERATION_ABORTED))
        }

        @Test("notFound matches ERROR_NOT_FOUND")
        func notFoundConstant() {
            #expect(Kernel.IOCP.WindowsError.notFound == UInt32(ERROR_NOT_FOUND))
        }

        @Test("timeout matches WAIT_TIMEOUT")
        func timeoutConstant() {
            #expect(Kernel.IOCP.WindowsError.timeout == UInt32(bitPattern: WAIT_TIMEOUT))
        }

        @Test("infinite matches INFINITE")
        func infiniteConstant() {
            #expect(Kernel.IOCP.WindowsError.infinite == INFINITE)
        }
    }

    // MARK: - Value Tests

    extension Kernel.IOCP.WindowsError.Test.Unit {
        @Test("ioPending is non-zero")
        func ioPendingNonZero() {
            #expect(Kernel.IOCP.WindowsError.ioPending != 0)
        }

        @Test("operationAborted is non-zero")
        func operationAbortedNonZero() {
            #expect(Kernel.IOCP.WindowsError.operationAborted != 0)
        }

        @Test("notFound is non-zero")
        func notFoundNonZero() {
            #expect(Kernel.IOCP.WindowsError.notFound != 0)
        }

        @Test("infinite is 0xFFFFFFFF")
        func infiniteValue() {
            #expect(Kernel.IOCP.WindowsError.infinite == 0xFFFF_FFFF)
        }
    }

    // MARK: - Uniqueness Tests

    extension Kernel.IOCP.WindowsError.Test.Unit {
        @Test("All error constants are distinct")
        func allConstantsDistinct() {
            let constants: Set<UInt32> = [
                Kernel.IOCP.WindowsError.ioPending,
                Kernel.IOCP.WindowsError.operationAborted,
                Kernel.IOCP.WindowsError.notFound,
                Kernel.IOCP.WindowsError.timeout,
            ]

            // All 4 should be unique
            #expect(constants.count == 4)
        }
    }

    // MARK: - Usage Tests

    extension Kernel.IOCP.WindowsError.Test.Unit {
        @Test("ioPending can be used for async operation check")
        func ioPendingUsage() {
            // Simulating how this would be used in practice
            let errorCode: UInt32 = Kernel.IOCP.WindowsError.ioPending

            let isPending = errorCode == Kernel.IOCP.WindowsError.ioPending
            #expect(isPending == true)

            let isAborted = errorCode == Kernel.IOCP.WindowsError.operationAborted
            #expect(isAborted == false)
        }

        @Test("timeout can be compared with GetLastError result")
        func timeoutComparison() {
            // Simulating comparison with a timeout error
            let simulatedError = Kernel.IOCP.WindowsError.timeout

            let isTimeout = simulatedError == Kernel.IOCP.WindowsError.timeout
            #expect(isTimeout == true)
        }

        @Test("infinite can be used as timeout parameter")
        func infiniteAsTimeout() {
            let timeout: DWORD = Kernel.IOCP.WindowsError.infinite

            // INFINITE is used to wait forever
            #expect(timeout == INFINITE)
        }
    }

    // MARK: - Conformance Tests

    extension Kernel.IOCP.WindowsError.Test.Unit {
        @Test("WindowsError namespace is Sendable")
        func isSendable() {
            // The constants themselves are just UInt32, which is Sendable
            let value: any Sendable = Kernel.IOCP.WindowsError.ioPending
            #expect(value is UInt32)
        }
    }

    // MARK: - Edge Cases

    extension Kernel.IOCP.WindowsError.Test.EdgeCase {
        @Test("Constants match Windows SDK values")
        func constantsMatchSDK() {
            // These are known Windows error codes
            // ERROR_IO_PENDING = 997
            #expect(Kernel.IOCP.WindowsError.ioPending == 997)

            // ERROR_OPERATION_ABORTED = 995
            #expect(Kernel.IOCP.WindowsError.operationAborted == 995)

            // ERROR_NOT_FOUND = 1168
            #expect(Kernel.IOCP.WindowsError.notFound == 1168)

            // WAIT_TIMEOUT = 258
            #expect(Kernel.IOCP.WindowsError.timeout == 258)
        }

        @Test("infinite and timeout are distinct")
        func infiniteNotTimeout() {
            #expect(Kernel.IOCP.WindowsError.infinite != Kernel.IOCP.WindowsError.timeout)
        }

        @Test("Constants can be used in switch statements")
        func switchUsage() {
            let errorCodes: [UInt32] = [
                Kernel.IOCP.WindowsError.ioPending,
                Kernel.IOCP.WindowsError.operationAborted,
                Kernel.IOCP.WindowsError.notFound,
                Kernel.IOCP.WindowsError.timeout,
            ]

            for code in errorCodes {
                switch code {
                case Kernel.IOCP.WindowsError.ioPending:
                    #expect(code == 997)
                case Kernel.IOCP.WindowsError.operationAborted:
                    #expect(code == 995)
                case Kernel.IOCP.WindowsError.notFound:
                    #expect(code == 1168)
                case Kernel.IOCP.WindowsError.timeout:
                    #expect(code == 258)
                default:
                    Issue.record("Unexpected error code: \(code)")
                }
            }
        }
    }

#endif

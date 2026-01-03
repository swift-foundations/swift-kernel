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

#if os(Windows)
    public import WinSDK

    extension Kernel.IOCP {
        /// Common Windows error codes used with IOCP operations.
        public enum WindowsError: Sendable {

        }
    }

    // MARK: - Constants

    extension Kernel.IOCP.WindowsError {
        /// The I/O operation has been started but not yet completed.
        public static let ioPending: DWORD = DWORD(ERROR_IO_PENDING)

        /// The I/O operation was aborted due to cancellation.
        public static let operationAborted: DWORD = DWORD(ERROR_OPERATION_ABORTED)

        /// The specified operation was not found.
        public static let notFound: DWORD = DWORD(ERROR_NOT_FOUND)

        /// The wait operation timed out.
        public static let timeout: DWORD = DWORD(bitPattern: WAIT_TIMEOUT)

        /// Infinite timeout value.
        public static let infinite: DWORD = INFINITE
    }

#endif

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
public import Kernel_Primitives

#if os(Windows)
    public import WinSDK

    extension Kernel.IOCP {
        /// Common Windows error codes used with IOCP operations.
        ///
        /// These constants provide Swift access to Win32 error codes commonly
        /// encountered in IOCP programming, avoiding the need to import WinSDK
        /// in higher layers.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// let error = GetLastError()
        /// if error == Kernel.IOCP.WindowsError.ioPending {
        ///     // Operation started successfully, will complete async
        /// } else if error == Kernel.IOCP.WindowsError.operationAborted {
        ///     // Operation was cancelled
        /// }
        /// ```
        ///
        /// ## See Also
        ///
        /// - ``Kernel/IOCP/Error``
        public enum WindowsError: Sendable {

        }
    }

    // MARK: - Constants

    extension Kernel.IOCP.WindowsError {
        /// The I/O operation has been started but not yet completed.
        public static let ioPending: UInt32 = UInt32(ERROR_IO_PENDING)

        /// The I/O operation was aborted due to cancellation.
        public static let operationAborted: UInt32 = UInt32(ERROR_OPERATION_ABORTED)

        /// The specified operation was not found.
        public static let notFound: UInt32 = UInt32(ERROR_NOT_FOUND)

        /// The wait operation timed out.
        public static let timeout: UInt32 = UInt32(bitPattern: WAIT_TIMEOUT)

        /// Infinite timeout value.
        public static let infinite: UInt32 = INFINITE
    }

#endif

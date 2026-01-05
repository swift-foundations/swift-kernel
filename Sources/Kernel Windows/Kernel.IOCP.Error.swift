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
        /// Errors from I/O completion port operations.
        ///
        /// Low-level errors from Windows IOCP operations. Each case wraps
        /// the underlying `Kernel.Error.Code` (Win32 error code) for
        /// platform-specific details. Convert to `Kernel.Error` for
        /// semantic error handling.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// do {
        ///     let port = try Kernel.IOCP.create()
        /// } catch let error as Kernel.IOCP.Error {
        ///     switch error {
        ///     case .create(let code):
        ///         print("CreateIoCompletionPort failed: \(code)")
        ///     case .timeout:
        ///         // Handle timeout
        ///     default:
        ///         throw Kernel.Error(error)  // Convert to semantic error
        ///     }
        /// }
        /// ```
        ///
        /// ## See Also
        ///
        /// - ``Kernel/IOCP``
        /// - ``Kernel/Error``
        /// - ``Kernel/Error/Code``
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create the I/O completion port.
            ///
            /// Returned by `CreateIoCompletionPort` when creating a new port.
            /// Common causes: system resource exhaustion.
            case create(Kernel.Error.Code)

            /// Failed to associate a handle with the IOCP.
            ///
            /// Returned by `CreateIoCompletionPort` when associating a handle.
            /// Common causes: handle already associated, invalid handle.
            case associate(Kernel.Error.Code)

            /// Failed to dequeue completion entries.
            ///
            /// Returned by `GetQueuedCompletionStatus[Ex]`. May indicate
            /// the port was closed or an invalid handle was used.
            case dequeue(Kernel.Error.Code)

            /// Failed to post a completion packet.
            ///
            /// Returned by `PostQueuedCompletionStatus`. May indicate
            /// the port is invalid or full.
            case post(Kernel.Error.Code)

            /// Failed to initiate an asynchronous read.
            ///
            /// Returned by `ReadFile` when the async operation could not
            /// be started. Does not include `ERROR_IO_PENDING` (which is normal).
            case read(Kernel.Error.Code)

            /// Failed to initiate an asynchronous write.
            ///
            /// Returned by `WriteFile` when the async operation could not
            /// be started. Does not include `ERROR_IO_PENDING` (which is normal).
            case write(Kernel.Error.Code)

            /// Failed to get the result of an overlapped operation.
            ///
            /// Returned by `GetOverlappedResult` when the operation
            /// failed or the parameters were invalid.
            case result(Kernel.Error.Code)

            /// The wait operation timed out.
            ///
            /// Returned when `GetQueuedCompletionStatus[Ex]` times out
            /// without receiving any completion packets.
            case timeout
        }
    }

    // MARK: - CustomStringConvertible

    extension Kernel.IOCP.Error: CustomStringConvertible {
        public var description: String {
            switch self {
            case .create(let code):
                return "CreateIoCompletionPort failed (\(code))"
            case .associate(let code):
                return "associate failed (\(code))"
            case .dequeue(let code):
                return "GetQueuedCompletionStatus failed (\(code))"
            case .post(let code):
                return "PostQueuedCompletionStatus failed (\(code))"
            case .read(let code):
                return "ReadFile failed (\(code))"
            case .write(let code):
                return "WriteFile failed (\(code))"
            case .result(let code):
                return "GetOverlappedResult failed (\(code))"
            case .timeout:
                return "operation timed out"
            }
        }
    }

    // MARK: - Last Error Helper

    extension Kernel.IOCP.Error {
        /// Gets the last Windows error code.
        ///
        /// Exposed so swift-io doesn't need to import WinSDK.
        @inlinable
        public static func last() -> UInt32 {
            GetLastError()
        }
    }

    // MARK: - Kernel.Error Conversion

    extension Kernel.Error {
        /// Creates a semantic error from an IOCP error.
        ///
        /// Maps to semantic cases where possible, falls back to `.platform` otherwise.
        public init(_ error: Kernel.IOCP.Error) {
            switch error {
            case .create(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .associate(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .dequeue(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .post(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .read(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .write(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .result(let code):
                self = Kernel.Error(code) ?? .platform(Kernel.Error.Unmapped.Error(code))
            case .timeout:
                self = .blocking(.wouldBlock)
            }
        }
    }

#endif

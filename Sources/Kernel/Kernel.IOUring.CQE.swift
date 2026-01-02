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

#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.IOUring {
        /// Swift wrapper for io_uring completion queue entry.
        ///
        /// A CQE contains the result of a completed I/O operation.
        /// This wrapper provides a Swift-native interface to the C `io_uring_cqe` struct.
        ///
        /// ## Usage
        ///
        /// CQEs are read from the CQ ring buffer:
        /// ```swift
        /// let cqePtr = ring.cqes.advanced(by: index)
        /// let cqe = Kernel.IOUring.CQE(cqePtr.pointee)
        /// if cqe.isSuccess {
        ///     print("Completed: \(cqe.result) bytes")
        /// }
        /// ```
        ///
        /// ## Thread Safety
        ///
        /// CQEs are value types that wrap a C struct. They should be read
        /// on the poll thread from the shared ring buffer.
        public struct CQE: Sendable {
            /// The underlying C struct.
            public let cValue: io_uring_cqe

            /// Creates a CQE from a C struct.
            @inlinable
            public init(_ cValue: io_uring_cqe) {
                self.cValue = cValue
            }
        }
    }

    // MARK: - Accessors

    extension Kernel.IOUring.CQE {
        /// User data from the corresponding SQE.
        ///
        /// This is the value set via `sqe.userData` when the operation was submitted.
        /// Typically used to recover the operation context (e.g., a pointer to Storage).
        @inlinable
        public var userData: UInt64 {
            cValue.user_data
        }

        /// Result of the operation.
        ///
        /// - For successful operations: the number of bytes transferred (or other success value)
        /// - For failed operations: a negative errno value
        @inlinable
        public var res: Int32 {
            cValue.res
        }

        /// CQE flags.
        ///
        /// Contains additional information about the completion.
        @inlinable
        public var flags: UInt32 {
            cValue.flags
        }
    }

    // MARK: - Result Interpretation

    extension Kernel.IOUring.CQE {
        /// Whether the operation completed successfully.
        @inlinable
        public var isSuccess: Bool {
            res >= 0
        }

        /// Whether the operation failed.
        @inlinable
        public var isError: Bool {
            res < 0
        }

        /// Whether the operation was cancelled.
        ///
        /// Note: ECANCELED = 125 on Linux, hardcoded to avoid @inlinable visibility issues.
        @inlinable
        public var isCancelled: Bool {
            res == -125  // ECANCELED
        }

        /// The result as a byte count (for read/write operations).
        ///
        /// Returns nil if the operation failed.
        @inlinable
        public var bytesTransferred: Int? {
            isSuccess ? Int(res) : nil
        }

        /// The errno value (for failed operations).
        ///
        /// Returns nil if the operation succeeded.
        @inlinable
        public var errno: Int32? {
            isError ? -res : nil
        }
    }

    // MARK: - CQE Flags

    extension Kernel.IOUring.CQE {
        /// Flags returned with completion queue entries.
        public struct Flags: OptionSet, Sendable {
            public let rawValue: UInt32

            @inlinable
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }

            /// Buffer ID is valid (buffer was selected from buffer group).
            public static let buffer = Flags(rawValue: 1 << 0)

            /// More CQEs will follow for this SQE (multishot).
            public static let more = Flags(rawValue: 1 << 1)

            /// Socket is in a readable state (recv multishot).
            public static let sockNonempty = Flags(rawValue: 1 << 2)

            /// Notification CQE (not a completion).
            public static let notif = Flags(rawValue: 1 << 3)
        }

        /// The CQE flags as a typed value.
        @inlinable
        public var typedFlags: Flags {
            Flags(rawValue: flags)
        }

        /// Whether this CQE indicates more completions will follow (multishot).
        @inlinable
        public var hasMore: Bool {
            typedFlags.contains(.more)
        }

        /// The buffer ID if a buffer was selected.
        ///
        /// Only valid when `.buffer` flag is set.
        @inlinable
        public var bufferID: UInt16? {
            guard typedFlags.contains(.buffer) else { return nil }
            return UInt16(truncatingIfNeeded: flags >> 16)
        }
    }

#endif

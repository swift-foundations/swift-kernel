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
public import Kernel_Primitives


#if canImport(Glibc) || canImport(Musl)

    #if canImport(Glibc)
        import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        import Musl
    #endif

    extension Kernel.IOUring.Completion.Queue {
        /// Swift wrapper for io_uring completion queue entry.
        ///
        /// An Entry contains the result of a completed I/O operation.
        /// This wrapper provides a Swift-native interface to the C `io_uring_cqe` struct.
        ///
        /// ## Usage
        ///
        /// Entries are read from the completion queue ring buffer:
        /// ```swift
        /// let entryPtr = ring.cqes.advanced(by: index)
        /// let entry = Kernel.IOUring.Completion.Queue.Entry(entryPtr.pointee)
        /// if entry.isSuccess {
        ///     print("Completed: \(entry.result) bytes")
        /// }
        /// ```
        ///
        /// ## Thread Safety
        ///
        /// Entries are value types that wrap a C struct. They should be read
        /// on the poll thread from the shared ring buffer.
        public struct Entry: Sendable {
            /// The underlying C struct.
            public let cValue: io_uring_cqe

            /// Creates an Entry from a C struct.
            @inlinable
            public init(_ cValue: io_uring_cqe) {
                self.cValue = cValue
            }
        }
    }

    // MARK: - Accessors

    extension Kernel.IOUring.Completion.Queue.Entry {
        /// User data from the corresponding submission queue entry.
        ///
        /// This is the value set via `entry.userData` when the operation was submitted.
        /// Typically used to recover the operation context (e.g., a pointer to Storage).
        @inlinable
        public var userData: Kernel.IOUring.UserData {
            Kernel.IOUring.UserData(rawValue: cValue.user_data)
        }

        /// Result of the operation.
        ///
        /// - For successful operations: the number of bytes transferred (or other success value)
        /// - For failed operations: a negative errno value
        @inlinable
        public var res: Int32 {
            cValue.res
        }

        /// Entry flags.
        ///
        /// Contains additional information about the completion.
        @inlinable
        public var flags: UInt32 {
            cValue.flags
        }
    }

    // MARK: - Result Interpretation

    extension Kernel.IOUring.Completion.Queue.Entry {
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

    // MARK: - Typed Flags Accessors

    extension Kernel.IOUring.Completion.Queue.Entry {
        /// The entry flags as a typed value.
        @inlinable
        public var typedFlags: Flags {
            Flags(rawValue: flags)
        }

        /// Whether this entry indicates more completions will follow (multishot).
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

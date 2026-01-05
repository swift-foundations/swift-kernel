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
        /// Errors from IOCP operations.
        public enum Error: Swift.Error, Sendable, Equatable, Hashable {
            /// Failed to create IOCP.
            case create(Kernel.Error.Code)

            /// Failed to associate handle with IOCP.
            case associate(Kernel.Error.Code)

            /// Failed to dequeue completions.
            case dequeue(Kernel.Error.Code)

            /// Failed to post completion.
            case post(Kernel.Error.Code)

            /// Failed to read.
            case read(Kernel.Error.Code)

            /// Failed to write.
            case write(Kernel.Error.Code)

            /// Failed to get result.
            case result(Kernel.Error.Code)

            /// Poll timed out.
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

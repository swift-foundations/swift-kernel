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
        /// Swift wrapper for Windows OVERLAPPED structure.
        ///
        /// The `OVERLAPPED` structure is used by Windows for asynchronous I/O
        /// operations. This wrapper provides a Swift-friendly interface while
        /// maintaining layout compatibility for the container-of pattern.
        public struct Overlapped: @unchecked Sendable {
            /// The underlying Windows OVERLAPPED structure.
            public var raw: OVERLAPPED

            /// Creates a zero-initialized overlapped structure.
            @inlinable
            public init() {
                raw = OVERLAPPED()
            }
        }
    }

    // MARK: - Accessors

    extension Kernel.IOCP.Overlapped {
        /// The 64-bit file offset for positioned I/O.
        @inlinable
        public var offset: Int64 {
            get { Int64(raw.Offset) | (Int64(raw.OffsetHigh) << 32) }
            set {
                raw.Offset = DWORD(truncatingIfNeeded: newValue)
                raw.OffsetHigh = DWORD(truncatingIfNeeded: newValue >> 32)
            }
        }
    }

#endif

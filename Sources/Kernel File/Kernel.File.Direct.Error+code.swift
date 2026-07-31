// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Error_Primitives

// MARK: - POSIX Translation from Syscall

extension Kernel.File.Direct.Error {
    /// Creates a semantic error from a raw syscall error.
    public init(from syscall: Syscall) {
        switch syscall {
        case .invalidDescriptor:
            self = .invalidHandle

        case .alignmentViolation(let operation):
            self = .platform(code: .posix(-1), operation: operation)

        case .notSupported:
            self = .notSupported

        case .platform(let code, let operation):
            self.init(code: code, operation: operation)
        }
    }

    /// Maps a platform error code to a semantic error.
    ///
    /// On POSIX legs the errno is classified here. On Windows the code is
    /// carried through unclassified: Win32 codes are not POSIX codes, and
    /// `Error.Code.POSIX` is not even reachable on that leg — its owner,
    /// ISO 9945 Core, is not in the Windows build graph. Direct I/O on
    /// Windows goes through `FILE_FLAG_NO_BUFFERING` and reports its own
    /// codes, so classification belongs to that owner rather than to a
    /// second mapping here.
    @usableFromInline
    internal init(code: Error_Primitives.Error.Code, operation: Operation) {
        #if os(Windows)
            self = .platform(code: code, operation: operation)
        #else
            switch code {
            case _ where code == .POSIX.EINVAL:
                self = .platform(code: code, operation: operation)

            case _ where code == .POSIX.EBADF:
                self = .invalidHandle

            case _ where Error_Primitives.Error.Code.POSIX.isENOTSUP(code):
                self = .notSupported

            default:
                self = .platform(code: code, operation: operation)
            }
        #endif
    }
}

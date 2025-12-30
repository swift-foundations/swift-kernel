//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

extension Kernel {
    /// Syscall wrappers for low-level OS operations.
    ///
    /// All functions in this namespace:
    /// - Use typed throws (`throws(Kernel.Error)`)
    /// - Are policy-free (no retry logic, no best-effort behavior)
    /// - Return raw values (callers interpret results)
    ///
    /// ## Invariants
    /// - **EOF**: `read`/`pread` return 0 on EOF (not an error)
    /// - **EINTR**: Returns `.interrupted` (higher layers decide retry policy)
    /// - **Partial writes**: `write`/`pwrite` may return fewer bytes than requested
    /// - **Close**: Invalid descriptor throws `.invalidDescriptor`
    public enum Syscalls {}
}

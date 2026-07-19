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

import Kernel
import Kernel_Test_Support
import Testing

extension Kernel.File.Flush {
    @Suite
    struct Test {
        @Suite struct Flush {}
        @Suite struct `Data` {}
        @Suite struct `Directory` {}
    }
}

// MARK: - flush(_:) Smoke

#if !os(Windows)

    extension Kernel.File.Flush.Test.Flush {
        @Test
        func `flush(_:) on a fresh tmp file succeeds on every platform`() throws {
            try KernelIOTest.withTempFile(prefix: "flush-smoke") { _, fd in
                // Cross-platform contract — no #if, single call.
                try Kernel.File.Flush.flush(fd)
            }
        }
    }

#endif

// MARK: - data(_:) Smoke

#if !os(Windows)

    extension Kernel.File.Flush.Test.Data {
        @Test
        func `data(_:) on a fresh tmp file succeeds on every platform`() throws {
            try KernelIOTest.withTempFile(prefix: "flush-data") { _, fd in
                // Cross-platform contract — no #if, single call.
                // POSIX: retry-wrapped fdatasync (Linux) / barrierFsync (Darwin).
                // Windows: FlushFileBuffers (strictly-stronger full flush).
                try Kernel.File.Flush.data(fd)
            }
        }
    }

#endif

// MARK: - directory(path:) Smoke

extension Kernel.File.Flush.Test.Directory {
    @Test
    func `directory(path:) on the system temp directory succeeds (POSIX) / no-ops (Windows)`() throws {
        let tempDir = Kernel.Temporary.directory
        try Path.scope(tempDir) { dirPath in
            // Cross-platform contract:
            //   POSIX: open(O_RDONLY) + fsync + auto-close with EINTR retry — must not throw.
            //   Windows: documented no-op — must not throw.
            try Kernel.File.Flush.directory(path: dirPath)
        }
    }
}

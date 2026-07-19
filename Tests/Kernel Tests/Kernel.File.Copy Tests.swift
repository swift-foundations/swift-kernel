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

import Kernel_Test_Support
import Testing

@testable import Kernel

// MARK: - Kernel.File.Copy Tests

extension Kernel.File.Copy {
    @Suite struct Test {
        @Suite struct Unit {}
        #if !os(Windows)
            @Suite struct `Edge Case` {}
        #endif
    }
}

// F-007: `copySymlink` used to wrap symlink creation in `try? Path.scope(target) { ... }`
// with an inner `do { ... } catch let error as X { } catch {}`. The outer `try?`
// silently discarded a `Path.scope` validation failure (the ONLY such failure —
// `Path.String.Conversion.Error.interiorNUL` — occurs when the target string
// contains an interior NUL byte), and the inner empty `catch {}` was a second
// layer of the same anti-pattern. Either failure mode let `copySymlink` — and
// therefore the public `Kernel.File.Copy.copy(..., followSymlinks: false)` —
// return success without ever creating the destination symlink.
//
// A real on-disk symlink cannot have an interior-NUL target: `symlink(2)` takes
// a NUL-terminated C string, so the kernel can never store a target containing
// an embedded NUL, and `readlink(2)` can therefore never hand one back. The
// exact `Path.scope` trigger is provably unreachable through the public API on
// any platform — not just this host — so it cannot be exercised as a real
// pre-fix-RED/post-fix-GREEN integration test. Two things are tested instead:
// (1) a direct unit test of `Path.scope` proving the precondition the fix
// relies on — that an interior-NUL string really does throw — and (2) real,
// reachable integration coverage of `copySymlink` through the public API: the
// happy path (proves removing `try?`/`catch {}` did not regress the normal
// case) and a real, reachable failure (destination parent directory does not
// exist) that must now surface as a thrown `Copy.Error` rather than silently
// succeeding.
#if !os(Windows)

    extension Kernel.File.Copy.Test.`Edge Case` {
        @Test func `Path scope rejects a target string containing an interior NUL byte`() {
            let targetWithNUL = "/tmp/before\0after"

            #expect(throws: (any Swift.Error).self) {
                try Path.scope(targetWithNUL) { (_: borrowing Path.Borrowed) in }
            }
        }
    }

    extension Kernel.File.Copy.Test.Unit {
        @Test func `copying a symlink with followSymlinks false recreates the link at the destination`() throws {
            let target = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-target")
            let source = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-src")
            let destination = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-dst")

            try Path.scope(target, source) { targetPath, sourcePath in
                try Kernel.Link.Symbolic.create(target: targetPath, at: sourcePath)
            }
            defer { try? Path.scope(source) { try? Kernel.File.Delete.delete($0) } }

            try Path.scope(source, destination) { sourcePath, destinationPath in
                try Kernel.File.Copy.copy(
                    from: sourcePath,
                    to: destinationPath,
                    options: .init(overwrite: false, copyAttributes: false, followSymlinks: false)
                )
            }
            defer { try? Path.scope(destination) { try? Kernel.File.Delete.delete($0) } }

            let readBackTarget = try Path.scope(destination) { destinationPath in
                Swift.String(try Kernel.Link.Symbolic.readTarget(at: destinationPath))
            }

            #expect(readBackTarget == target)
        }

        @Test func `copying a symlink to a destination whose parent does not exist throws instead of silently succeeding`() throws {
            let target = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-target")
            let source = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-src")
            let destination =
                Kernel.Temporary.directory + "/kernel-copy-symlink-missing-parent-\(Int.random(in: 0..<Int.max))/dst"

            try Path.scope(target, source) { targetPath, sourcePath in
                try Kernel.Link.Symbolic.create(target: targetPath, at: sourcePath)
            }
            defer { try? Path.scope(source) { try? Kernel.File.Delete.delete($0) } }

            typealias E = Path.String.Error<Kernel.File.Copy.Error>

            expectThrows(
                { (error: E) in
                    #expect(error.body != nil)
                },
                { () throws(E) in
                    try Path.scope(source, destination) { (sourcePath, destinationPath) throws(Kernel.File.Copy.Error) in
                        try Kernel.File.Copy.copy(
                            from: sourcePath,
                            to: destinationPath,
                            options: .init(overwrite: false, copyAttributes: false, followSymlinks: false)
                        )
                    }
                }
            )

            // The destination must not exist — the prior bug's failure mode was
            // "reports success, creates nothing"; this proves the fix doesn't
            // instead regress into "throws, but the link got created anyway".
            let destinationExists = (try? Path.scope(destination) { try? Kernel.File.Stats.lget(path: $0) }) != nil
            #expect(!destinationExists)
        }
    }

#endif

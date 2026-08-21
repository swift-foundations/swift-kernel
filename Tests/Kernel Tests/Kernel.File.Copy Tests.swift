import Kernel_Test_Support
import Testing

@testable import Kernel

extension Kernel.File.Copy {
    @Suite struct Test {
        @Suite struct Unit {}
        #if !os(Windows)
            @Suite struct `Edge Case` {}
        #endif
    }
}

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
        @Test
        func `copying a symlink with followSymlinks false recreates the link at the destination`()
            throws
        {
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

        @Test
        func
            `copying a symlink to a destination whose parent does not exist throws instead of silently succeeding`()
            throws
        {
            let target = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-target")
            let source = Kernel.Temporary.filePath(prefix: "kernel-copy-symlink-src")
            let destination =
                Kernel.Temporary.directory
                + "/kernel-copy-symlink-missing-parent-\(Int.random(in: 0..<Int.max))/dst"

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
                    try Path.scope(source, destination) {
                        sourcePath,
                        destinationPath throws(Kernel.File.Copy.Error) in
                        try Kernel.File.Copy.copy(
                            from: sourcePath,
                            to: destinationPath,
                            options: .init(
                                overwrite: false,
                                copyAttributes: false,
                                followSymlinks: false
                            )
                        )
                    }
                }
            )

            let destinationExists =
                (try? Path.scope(destination) { try? Kernel.File.Stats.lget(path: $0) }) != nil
            #expect(!destinationExists)
        }
    }

#endif

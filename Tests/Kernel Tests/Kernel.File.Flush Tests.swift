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

#if !os(Windows)

    extension Kernel.File.Flush.Test.Flush {
        @Test
        func `flush(_:) on a fresh tmp file succeeds on every platform`() throws {
            try KernelIOTest.withTempFile(prefix: "flush-smoke") { _, fd in

                try Kernel.File.Flush.flush(fd)
            }
        }
    }

#endif

#if !os(Windows)

    extension Kernel.File.Flush.Test.Data {
        @Test
        func `data(_:) on a fresh tmp file succeeds on every platform`() throws {
            try KernelIOTest.withTempFile(prefix: "flush-data") { _, fd in

                try Kernel.File.Flush.data(fd)
            }
        }
    }

#endif

extension Kernel.File.Flush.Test.Directory {
    @Test
    func `directory(path:) on the system temp directory succeeds (POSIX) / no-ops (Windows)`()
        throws
    {
        let tempDir = Kernel.Temporary.directory
        try Path.scope(tempDir) { dirPath in

            try Kernel.File.Flush.directory(path: dirPath)
        }
    }
}

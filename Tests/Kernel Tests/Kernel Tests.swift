import Kernel_Test_Support
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Kernel

extension Kernel {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Kernel.Test.Unit {
    @Test
    func `Kernel namespace exists`() {

        _ = Kernel.self
    }

    @Test
    func `open and close file`() throws {
        let pathString = Kernel.Temporary.filePath(prefix: "kernel-test")

        try Path.scope(pathString) { path in

            let fd = try Kernel.File.Open.open(
                path: path,
                mode: .readWrite,
                options: [.create, .truncate],
                permissions: .standard
            )

            do {
                let v = fd.isValid
                #expect(v)
            }

            try Kernel.Close.close(fd)

            try? Kernel.File.Delete.delete(path)
        }
    }

    @Test
    func `open nonexistent file throws path error`() throws {
        #if os(Windows)
            let pathString = "C:\\nonexistent\\path\\that\\does\\not\\exist\\file.txt"
        #else
            let pathString = "/nonexistent/path/that/does/not/exist/file.txt"
        #endif

        try Path.scope(pathString) { path in
            #expect(throws: (any Swift.Error).self) {
                try Kernel.File.Open.open(
                    path: path,
                    mode: .read,
                    options: [],
                    permissions: 0
                )
            }
        }
    }

    @Test
    func `write and read data`() throws {
        let pathString = Kernel.Temporary.filePath(prefix: "kernel-test-rw")
        let testData: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]

        try Path.scope(pathString) { path in

            let fd = try Kernel.File.Open.open(
                path: path,
                mode: .readWrite,
                options: [.create, .truncate],
                permissions: .standard
            )

            defer {
                try? Kernel.File.Delete.delete(path)
            }

            let written = try testData.withUnsafeBytes { buffer in
                try Kernel.IO.Write.write(fd, from: buffer)
            }
            #expect(written == testData.count)

            var readBuffer = [UInt8](repeating: 0, count: testData.count)
            let bytesRead = try readBuffer.withUnsafeMutableBytes { buffer in
                try Kernel.IO.Read.pread(fd, into: buffer, at: 0)
            }

            #expect(bytesRead == testData.count)
            #expect(readBuffer == testData)
        }
    }

    @Test
    func `read returns 0 on EOF`() throws {
        let pathString = Kernel.Temporary.filePath(prefix: "kernel-test-eof")

        try Path.scope(pathString) { path in

            let fd = try Kernel.File.Open.open(
                path: path,
                mode: .readWrite,
                options: [.create, .truncate],
                permissions: .standard
            )

            defer {
                try? Kernel.File.Delete.delete(path)
            }

            var buffer = [UInt8](repeating: 0, count: 100)
            let bytesRead = try buffer.withUnsafeMutableBytes { buf in
                try Kernel.IO.Read.pread(fd, into: buf, at: 0)
            }

            #expect(bytesRead == 0)
        }
    }
}

extension Kernel.Test.`Edge Case` {
    @Test
    func `close invalid descriptor throws`() {
        #expect(throws: (any Swift.Error).self) {
            try Kernel.Close.close(.invalid)
        }
    }

    @Test
    func `read from invalid descriptor throws`() {
        var buffer = [UInt8](repeating: 0, count: 10)
        #expect(throws: (any Swift.Error).self) {
            try buffer.withUnsafeMutableBytes { buf in
                try Kernel.IO.Read.read(.invalid, into: buf)
            }
        }
    }

    @Test
    func `write to invalid descriptor throws`() {
        let data: [UInt8] = [1, 2, 3]
        #expect(throws: (any Swift.Error).self) {
            try data.withUnsafeBytes { buf in
                try Kernel.IO.Write.write(.invalid, from: buf)
            }
        }
    }
}

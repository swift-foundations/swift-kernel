#if !os(Windows)

public import Kernel

extension Kernel.Event {

    public enum Test {

        public struct PipeError: Swift.Error, Sendable {
            public init() {}
        }

        public static func makePipe() throws -> Kernel.Pipe.Descriptors {
            do {
                return try Kernel.Pipe.pipe()
            } catch {
                throw PipeError()
            }
        }

        public static func closeNoThrow(_ fd: consuming Kernel.Descriptor) {
            try? Kernel.Close.close(fd)
        }

        public static func writeByte(_ fd: borrowing Kernel.Descriptor, value: UInt8 = 1) {
            var byte = value
            _ = withUnsafeBytes(of: &byte) { buffer in
                try? unsafe POSIX.Kernel.IO.Write.write(fd, from: buffer)
            }
        }

        public static func readDrain(_ fd: borrowing Kernel.Descriptor) {
            var byte: UInt8 = 0
            _ = withUnsafeMutableBytes(of: &byte) { buffer in
                try? unsafe POSIX.Kernel.IO.Read.read(fd, into: buffer)
            }
        }
    }
}

#endif

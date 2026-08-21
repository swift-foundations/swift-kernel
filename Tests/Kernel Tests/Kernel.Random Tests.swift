import Kernel
import Standard_Library_Extensions
import Testing

extension Random {
    @Suite
    struct Test {
        @Suite struct Fill {}
    }
}

extension Random.Test.Fill {
    @Test
    func `fill(_:) on a 32-byte buffer produces non-zero bytes on every platform`() throws(Random
        .Error)
    {

        var buffer: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)

        try withUnsafeMutableBytes(of: &buffer) { raw throws(Random.Error) in
            try unsafe Random.fill(raw)
        }
        #expect(buffer != (0, 0, 0, 0))
    }

    @Test
    func `fill(_:) on an empty buffer is a no-op`() throws(Random.Error) {
        let buffer = unsafe UnsafeMutableRawBufferPointer(start: nil, count: 0)
        try unsafe Random.fill(buffer)
    }

    @Test
    func `successive fill(_:) calls produce different bytes`() throws(Random.Error) {
        var first: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        var second: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        try withUnsafeMutableBytes(of: &first) { raw throws(Random.Error) in
            try unsafe Random.fill(raw)
        }
        try withUnsafeMutableBytes(of: &second) { raw throws(Random.Error) in
            try unsafe Random.fill(raw)
        }
        #expect(first != second)
    }
}

import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

extension Kernel.File.Direct.Requirements.Alignment.Buffer {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Buffer.Test.Unit {
    @Test
    func `Buffer type exists`() {
        let _: Kernel.File.Direct.Requirements.Alignment.Buffer.Type =
            Kernel.File.Direct.Requirements.Alignment.Buffer.self
    }

    @Test
    func `isAligned method exists`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let buffer = alignment.buffer
        let bytes = [UInt8](repeating: 0, count: 4096)
        bytes.withUnsafeBytes { pointer in
            _ = buffer.isAligned(Memory.Address(pointer.baseAddress!))
        }
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Buffer.Test.Unit {
    @Test
    func `Buffer is Sendable`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let buffer: any Sendable = alignment.buffer
        #expect(buffer is Kernel.File.Direct.Requirements.Alignment.Buffer)
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Buffer.Test.EdgeCase {
    @Test
    func `buffer accessor returns consistent value`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let buffer1 = alignment.buffer
        let buffer2 = alignment.buffer

        let bytes = [UInt8](repeating: 0, count: 4096)
        bytes.withUnsafeBytes { pointer in
            let addr = Memory.Address(pointer.baseAddress!)
            let result1 = buffer1.isAligned(addr)
            let result2 = buffer2.isAligned(addr)
            #expect(result1 == result2)
        }
    }
}

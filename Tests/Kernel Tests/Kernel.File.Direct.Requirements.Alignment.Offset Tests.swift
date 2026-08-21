import Kernel
import Kernel_Test_Support
import Tagged_Primitives_Standard_Library_Integration
import Testing

extension Kernel.File.Direct.Requirements.Alignment.Offset {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Offset.Test.Unit {
    @Test
    func `Offset type exists`() {
        let _: Kernel.File.Direct.Requirements.Alignment.Offset.Type =
            Kernel.File.Direct.Requirements.Alignment.Offset.self
    }

    @Test
    func `isAligned method exists`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let offset = alignment.offset
        _ = offset.isAligned(0)
    }

    @Test
    func `isAligned returns true for aligned offset`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let offset = alignment.offset
        #expect(offset.isAligned(0) == true)
        #expect(offset.isAligned(4096) == true)
        #expect(offset.isAligned(8192) == true)
    }

    @Test
    func `isAligned returns false for unaligned offset`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let offset = alignment.offset
        #expect(offset.isAligned(1) == false)
        #expect(offset.isAligned(100) == false)
        #expect(offset.isAligned(4097) == false)
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Offset.Test.Unit {
    @Test
    func `Offset is Sendable`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let offset: any Sendable = alignment.offset
        #expect(offset is Kernel.File.Direct.Requirements.Alignment.Offset)
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Offset.Test.EdgeCase {
    @Test
    func `offset accessor returns consistent value`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let offset1 = alignment.offset
        let offset2 = alignment.offset
        #expect(offset1.isAligned(4096) == offset2.isAligned(4096))
    }

    @Test
    func `zero offset is always aligned`() {
        let alignments: [Memory.Alignment] = [.`512`, .`1024`, .`4096`, .`8192`]
        for value in alignments {
            let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: value)
            #expect(alignment.offset.isAligned(0) == true)
        }
    }
}

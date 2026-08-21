import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

extension Kernel.File.Direct.Requirements.Alignment {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Test.Unit {
    @Test
    func `init with explicit values`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`512`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`512`
        )
        #expect(alignment.bufferAlignment == .`512`)
        #expect(alignment.offsetAlignment == .`4096`)
        #expect(alignment.lengthMultiple == .`512`)
    }

    @Test
    func `init with uniform alignment`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        #expect(alignment.bufferAlignment == .`4096`)
        #expect(alignment.offsetAlignment == .`4096`)
        #expect(alignment.lengthMultiple == .`4096`)
    }

    @Test
    func `bufferAlignment property`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`512`)
        #expect(alignment.bufferAlignment == .`512`)
    }

    @Test
    func `offsetAlignment property`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        #expect(alignment.offsetAlignment == .`4096`)
    }

    @Test
    func `lengthMultiple property`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        #expect(alignment.lengthMultiple == .`4096`)
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Test.Unit {
    @Test
    func `buffer accessor exists`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let _ = alignment.buffer
    }

    @Test
    func `offset accessor exists`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let _ = alignment.offset
    }

    @Test
    func `length accessor exists`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let _ = alignment.length
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Test.Unit {
    @Test
    func `Alignment is Sendable`() {
        let alignment: any Sendable = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        #expect(alignment is Kernel.File.Direct.Requirements.Alignment)
    }

    @Test
    func `Alignment is Equatable`() {
        let a = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let b = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let c = Kernel.File.Direct.Requirements.Alignment(uniform: .`512`)
        #expect(a == b)
        #expect(a != c)
    }
}

extension Kernel.File.Direct.Requirements.Alignment.Test.EdgeCase {
    @Test
    func `alignments with different buffer values are distinct`() {
        let a = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`512`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`4096`
        )
        let b = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`4096`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`4096`
        )
        #expect(a != b)
    }

    @Test
    func `alignments with different offset values are distinct`() {
        let a = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`4096`,
            offsetAlignment: .`512`,
            lengthMultiple: .`4096`
        )
        let b = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`4096`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`4096`
        )
        #expect(a != b)
    }

    @Test
    func `alignments with different length values are distinct`() {
        let a = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`4096`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`512`
        )
        let b = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`4096`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`4096`
        )
        #expect(a != b)
    }

    @Test
    func `uniform alignment equals explicit with same values`() {
        let uniform = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let explicit = Kernel.File.Direct.Requirements.Alignment(
            bufferAlignment: .`4096`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`4096`
        )
        #expect(uniform == explicit)
    }
}

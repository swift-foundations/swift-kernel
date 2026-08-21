import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

extension Kernel.File.Direct.Requirements {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Requirements.Test.Unit {
    @Test
    func `known case exists`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let requirements = Kernel.File.Direct.Requirements.known(alignment)
        if case .known = requirements {

        } else {
            Issue.record("Expected .known case")
        }
    }

    @Test
    func `unknown case exists`() {
        let requirements = Kernel.File.Direct.Requirements.unknown(reason: .platformUnsupported)
        if case .unknown = requirements {

        } else {
            Issue.record("Expected .unknown case")
        }
    }
}

extension Kernel.File.Direct.Requirements.Test.Unit {
    @Test
    func `init with explicit alignment values`() {
        let requirements = Kernel.File.Direct.Requirements(
            bufferAlignment: .`512`,
            offsetAlignment: .`4096`,
            lengthMultiple: .`512`
        )
        if case .known(let alignment) = requirements {
            #expect(alignment.bufferAlignment == .`512`)
            #expect(alignment.offsetAlignment == .`4096`)
            #expect(alignment.lengthMultiple == .`512`)
        } else {
            Issue.record("Expected .known case")
        }
    }

    @Test
    func `init with uniform alignment`() {
        let requirements = Kernel.File.Direct.Requirements(uniformAlignment: .`4096`)
        if case .known(let alignment) = requirements {
            #expect(alignment.bufferAlignment == .`4096`)
            #expect(alignment.offsetAlignment == .`4096`)
            #expect(alignment.lengthMultiple == .`4096`)
        } else {
            Issue.record("Expected .known case")
        }
    }
}

extension Kernel.File.Direct.Requirements.Test.Unit {
    @Test
    func `Requirements is Sendable`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let requirements: any Sendable = Kernel.File.Direct.Requirements.known(alignment)
        #expect(requirements is Kernel.File.Direct.Requirements)
    }

    @Test
    func `Requirements is Equatable`() {
        let align1 = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let align2 = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let a = Kernel.File.Direct.Requirements.known(align1)
        let b = Kernel.File.Direct.Requirements.known(align2)
        let c = Kernel.File.Direct.Requirements.unknown(reason: .platformUnsupported)
        #expect(a == b)
        #expect(a != c)
    }
}

extension Kernel.File.Direct.Requirements.Test.Unit {
    @Test
    func `Alignment type exists`() {
        let _: Kernel.File.Direct.Requirements.Alignment.Type = Kernel.File.Direct.Requirements
            .Alignment.self
    }

    @Test
    func `Reason type exists`() {
        let _: Kernel.File.Direct.Requirements.Reason.Type = Kernel.File.Direct.Requirements.Reason
            .self
    }
}

extension Kernel.File.Direct.Requirements.Test.EdgeCase {
    @Test
    func `known with different alignments are distinct`() {
        let align1 = Kernel.File.Direct.Requirements.Alignment(uniform: .`512`)
        let align2 = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let req1 = Kernel.File.Direct.Requirements.known(align1)
        let req2 = Kernel.File.Direct.Requirements.known(align2)
        #expect(req1 != req2)
    }

    @Test
    func `unknown with different reasons are distinct`() {
        let req1 = Kernel.File.Direct.Requirements.unknown(reason: .platformUnsupported)
        let req2 = Kernel.File.Direct.Requirements.unknown(reason: .sectorSizeUndetermined)
        #expect(req1 != req2)
    }

    @Test
    func `known and unknown are distinct`() {
        let align = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let known = Kernel.File.Direct.Requirements.known(align)
        let unknown = Kernel.File.Direct.Requirements.unknown(reason: .platformUnsupported)
        #expect(known != unknown)
    }
}

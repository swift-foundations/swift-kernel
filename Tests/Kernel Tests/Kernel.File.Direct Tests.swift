import Error_Primitives
import Kernel_Test_Support
import Path_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Kernel

extension Kernel.File.Direct {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Test.Unit {
    @Test
    func `Direct namespace exists`() {
        _ = Kernel.File.Direct.self
    }

    @Test
    func `Direct is an enum`() {
        let _: Kernel.File.Direct.Type = Kernel.File.Direct.self
    }
}

extension Kernel.File.Direct.Test.Unit {
    @Test
    func `Direct.Capability type exists`() {
        let _: Kernel.File.Direct.Capability.Type = Kernel.File.Direct.Capability.self
    }

    @Test
    func `Direct.Mode type exists`() {
        let _: Kernel.File.Direct.Mode.Type = Kernel.File.Direct.Mode.self
    }

    @Test
    func `Direct.Requirements type exists`() {
        let _: Kernel.File.Direct.Requirements.Type = Kernel.File.Direct.Requirements.self
    }

    @Test
    func `Direct.Error type exists`() {
        let _: Kernel.File.Direct.Error.Type = Kernel.File.Direct.Error.self
    }
}

extension Kernel.File.Direct.Test.Unit {
    @Test
    func `direct mode resolved is equatable`() {
        #expect(Kernel.File.Direct.Mode.Resolved.buffered == .buffered)
        #expect(Kernel.File.Direct.Mode.Resolved.direct == .direct)
        #expect(Kernel.File.Direct.Mode.Resolved.uncached == .uncached)
        #expect(Kernel.File.Direct.Mode.Resolved.buffered != .direct)
    }

    @Test
    func `requirements known case`() {
        let alignment = Kernel.File.Direct.Requirements.Alignment(uniform: .`4096`)
        let requirements = Kernel.File.Direct.Requirements.known(alignment)

        if case .known(let a) = requirements {
            #expect(a.bufferAlignment == .`4096`)
        } else {
            Issue.record("Expected .known case")
        }
    }

    @Test
    func `requirements unknown case`() {
        let requirements = Kernel.File.Direct.Requirements.unknown(reason: .platformUnsupported)

        if case .unknown(let reason) = requirements {
            #expect(reason == .platformUnsupported)
        } else {
            Issue.record("Expected .unknown case")
        }
    }
}

import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

extension Kernel.File.Direct.Mode.Resolved {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Mode.Resolved.Test.Unit {
    @Test
    func `direct case exists`() {
        let resolved = Kernel.File.Direct.Mode.Resolved.direct
        if case .direct = resolved {

        } else {
            Issue.record("Expected .direct case")
        }
    }

    @Test
    func `uncached case exists`() {
        let resolved = Kernel.File.Direct.Mode.Resolved.uncached
        if case .uncached = resolved {

        } else {
            Issue.record("Expected .uncached case")
        }
    }

    @Test
    func `buffered case exists`() {
        let resolved = Kernel.File.Direct.Mode.Resolved.buffered
        if case .buffered = resolved {

        } else {
            Issue.record("Expected .buffered case")
        }
    }
}

extension Kernel.File.Direct.Mode.Resolved.Test.Unit {
    @Test
    func `Resolved is Sendable`() {
        let resolved: any Sendable = Kernel.File.Direct.Mode.Resolved.buffered
        #expect(resolved is Kernel.File.Direct.Mode.Resolved)
    }

    @Test
    func `Resolved is Equatable`() {
        let a = Kernel.File.Direct.Mode.Resolved.buffered
        let b = Kernel.File.Direct.Mode.Resolved.buffered
        let c = Kernel.File.Direct.Mode.Resolved.direct
        #expect(a == b)
        #expect(a != c)
    }
}

extension Kernel.File.Direct.Mode.Resolved.Test.EdgeCase {
    @Test
    func `all resolved modes are distinct`() {
        let cases: [Kernel.File.Direct.Mode.Resolved] = [
            .direct,
            .uncached,
            .buffered,
        ]

        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j])
            }
        }
    }
}

import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

extension Kernel.File.Direct.Mode.Policy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

extension Kernel.File.Direct.Mode.Policy.Test.Unit {
    @Test
    func `fallbackToBuffered case exists`() {
        let policy = Kernel.File.Direct.Mode.Policy.fallbackToBuffered
        if case .fallbackToBuffered = policy {

        } else {
            Issue.record("Expected .fallbackToBuffered case")
        }
    }

    @Test
    func `errorOnViolation case exists`() {
        let policy = Kernel.File.Direct.Mode.Policy.errorOnViolation
        if case .errorOnViolation = policy {

        } else {
            Issue.record("Expected .errorOnViolation case")
        }
    }
}

extension Kernel.File.Direct.Mode.Policy.Test.Unit {
    @Test
    func `Policy is Sendable`() {
        let policy: any Sendable = Kernel.File.Direct.Mode.Policy.fallbackToBuffered
        #expect(policy is Kernel.File.Direct.Mode.Policy)
    }

    @Test
    func `Policy is Equatable`() {
        let a = Kernel.File.Direct.Mode.Policy.fallbackToBuffered
        let b = Kernel.File.Direct.Mode.Policy.fallbackToBuffered
        let c = Kernel.File.Direct.Mode.Policy.errorOnViolation
        #expect(a == b)
        #expect(a != c)
    }
}

extension Kernel.File.Direct.Mode.Policy.Test.EdgeCase {
    @Test
    func `all policies are distinct`() {
        let fallback = Kernel.File.Direct.Mode.Policy.fallbackToBuffered
        let error = Kernel.File.Direct.Mode.Policy.errorOnViolation
        #expect(fallback != error)
    }
}

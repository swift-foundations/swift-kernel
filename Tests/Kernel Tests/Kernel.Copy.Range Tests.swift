#if os(Linux)

    import Testing
    import Tagged_Primitives_Standard_Library_Integration
    import Kernel

    extension Kernel.Copy.Range {
        @Suite
        struct Test {
            @Suite struct Unit {}
            @Suite struct EdgeCase {}
        }
    }

    extension Kernel.Copy.Range.Test.Unit {
        @Test
        func `Range namespace exists`() {

            _ = Kernel.Copy.Range.self
        }

        @Test
        func `Range is an enum`() {
            let _: Kernel.Copy.Range.Type = Kernel.Copy.Range.self
        }

    }

#endif

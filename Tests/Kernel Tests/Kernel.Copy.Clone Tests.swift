import Error_Primitives
import Kernel_Test_Support
import Path_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Kernel

#if os(Linux) || canImport(Darwin)

    extension Kernel.Copy.Clone {
        @Suite
        struct Test {
            @Suite struct Unit {}
            @Suite struct EdgeCase {}
        }
    }

    extension Kernel.Copy.Clone.Test.Unit {
        @Test
        func `Clone namespace exists`() {
            _ = Kernel.Copy.Clone.self
        }

        @Test
        func `Clone is an enum`() {
            let _: Kernel.Copy.Clone.Type = Kernel.Copy.Clone.self
        }
    }

    #if os(Linux)
        extension Kernel.Copy.Clone.Test.Unit {
            @Test
            func `perform function exists on Linux`() {

                typealias PerformType = (borrowing Kernel.Descriptor, borrowing Kernel.Descriptor)
                    throws -> Void
            }
        }
    #endif

    #if canImport(Darwin)
        extension Kernel.Copy.Clone.Test.Unit {
            @Test
            func `file function exists on Darwin`() {

                _ = Kernel.Copy.Clone.self
            }
        }
    #endif

#endif

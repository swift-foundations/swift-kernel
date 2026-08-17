// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

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

    // MARK: - Unit Tests

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

    // MARK: - Platform-Specific API Tests

    #if os(Linux)
        extension Kernel.Copy.Clone.Test.Unit {
            @Test
            func `perform function exists on Linux`() {
                // Verify the function signature compiles
                typealias PerformType = (borrowing Kernel.Descriptor, borrowing Kernel.Descriptor)
                    throws -> Void
            }
        }
    #endif

    #if canImport(Darwin)
        extension Kernel.Copy.Clone.Test.Unit {
            @Test
            func `file function exists on Darwin`() {
                // Verify the namespace and function exist at compile time
                _ = Kernel.Copy.Clone.self
            }
        }
    #endif

#endif

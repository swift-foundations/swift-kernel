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

#if os(Linux)
    // Tests use Apple native Testing framework
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

    // MARK: - Unit Tests

    extension Kernel.Copy.Range.Test.Unit {
        @Test
        func `Range namespace exists`() {
            // Kernel.Copy.Range is a public enum namespace (Linux only)
            _ = Kernel.Copy.Range.self
        }

        @Test
        func `Range is an enum`() {
            let _: Kernel.Copy.Range.Type = Kernel.Copy.Range.self
        }

        // NOTE: Kernel.Copy.Range.copy() is not yet implemented; this
        // family currently declares vocabulary only (namespace + errors).
        // Signature verification belongs with the platform-specific
        // implementation once it lands.
    }

#endif

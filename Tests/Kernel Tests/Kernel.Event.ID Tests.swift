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

// Windows has no Kernel.Event (epoll/kqueue vocabulary is POSIX-only) and no
// Kernel.Pipe; gated whole-file to match the convention used elsewhere for
// this target's POSIX-only surfaces (e.g. Tests/Support/Kernel.Event.Test.Support.swift).
#if !os(Windows)

    @_spi(Syscall) import Error_Primitives
    import Kernel_Test_Support
    @_spi(Syscall) import Path_Primitives
    import Tagged_Primitives_Standard_Library_Integration
    import Testing

    // Descriptor._rawValue is @_spi(Syscall)-gated (declared in POSIX Kernel
    // Descriptor, re-exported by Kernel via @_exported import).
    @testable @_spi(Syscall) import Kernel

    // Kernel.Event.ID is a typealias to Tagged<Kernel.Event, UInt>
    // Test struct pattern cannot be used on typealiases

    @Suite("Kernel.Event.ID Tests")
    struct EventIDTests {

        // MARK: - Basic Initialization

        @Test
        func `ID can be created from UInt literal`() {
            let id: Kernel.Event.ID = 42
            #expect(id == 42)
        }

        @Test
        func `ID zero is valid`() {
            let id: Kernel.Event.ID = 0
            #expect(id == 0)
        }

        @Test
        func `ID max value`() {
            let id = Kernel.Event.ID(_unchecked: UInt.max)
            #expect(id.underlying == UInt.max)
        }

        // MARK: - Descriptor Conversion

        @Test
        func `ID from descriptor reflects the fd raw value`() throws {
            // Use a real owned descriptor from pipe(2) so the raw value read
            // does not alias an unrelated fd. pipe goes out of scope at function
            // exit; both ends close cleanly through their respective
            // Kernel.Descriptor deinits.
            let pipe = try Kernel.Pipe.pipe()
            let id = Kernel.Event.ID(pipe.read._rawValue)
            #expect(id.underlying == UInt(bitPattern: Int(pipe.read._rawValue)))
        }

        @Test
        func `Round-trip from descriptor through ID is symmetric`() throws {
            // Verify the round-trip mathematically: the ID's raw value fits in
            // Int32 and the bit pattern matches the original descriptor's fd.
            // There is no reverse ID -> Descriptor conversion in the current
            // shape, so this checks the bit pattern directly rather than
            // reconstructing a Descriptor (which would also alias pipe.read
            // and double-close at scope exit).
            let pipe = try Kernel.Pipe.pipe()
            let originalRaw = pipe.read._rawValue
            let id = Kernel.Event.ID(pipe.read._rawValue)
            #expect(id.underlying <= UInt(Int32.max))
            #expect(Int32(id.underlying) == originalRaw)
        }

        // MARK: - Conformances

        @Test
        func `ID is Equatable`() {
            let a: Kernel.Event.ID = 42
            let b: Kernel.Event.ID = 42
            let c: Kernel.Event.ID = 43
            #expect(a == b)
            #expect(a != c)
        }

        @Test
        func `ID is Hashable`() {
            var set = Set<Kernel.Event.ID>()
            set.insert(Kernel.Event.ID(_unchecked: 1))
            set.insert(Kernel.Event.ID(_unchecked: 2))
            set.insert(Kernel.Event.ID(_unchecked: 1))  // duplicate
            #expect(set.count == 2)
        }

        @Test
        func `ID is Sendable`() {
            let id: Kernel.Event.ID = 42
            let sendable: any Sendable = id
            #expect(sendable is Kernel.Event.ID)
        }

        @Test
        func `ID is Comparable`() {
            let a: Kernel.Event.ID = 10
            let b: Kernel.Event.ID = 20
            #expect(a < b)
            #expect(b > a)
        }
    }

#endif

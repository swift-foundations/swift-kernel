// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Kernel_Test_Support
import Testing

@testable import Kernel

// MARK: - Kernel.Event.Source Tests

extension Kernel.Event.Source {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite(
            .disabled(
                if: Toolchain.hasTaggedMetadataSIGSEGV,

            )
        )
        struct Integration {}
    }
}

// MARK: - Integration (creates real kernel resources)

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

    extension Kernel.Event.Source.Test.Integration {
        @Test func `platform creates kqueue source`() throws {
            let source = try Kernel.Event.Source.platform()
            _ = source
        }

        @Test func `kqueue factory creates valid source`() throws {
            let source = try Kernel.Event.Source.kqueue()
            _ = source
        }

        @Test func `kqueue factory accepts custom max events`() throws {
            let source = try Kernel.Event.Source.kqueue(maxEvents: 64)
            _ = source
        }
    }

#elseif os(Linux)

    extension Kernel.Event.Source.Test.Integration {
        @Test func `platform creates epoll source`() throws {
            let source = try Kernel.Event.Source.platform()
            _ = source
        }

        @Test func `epoll factory creates valid source`() throws {
            let source = try Kernel.Event.Source.epoll()
            _ = source
        }

        @Test func `epoll factory accepts custom max events`() throws {
            let source = try Kernel.Event.Source.epoll(maxEvents: 64)
            _ = source
        }
    }

#endif

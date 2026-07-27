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

import Kernel
import Testing

extension Kernel.Socket.Address.Info {
    @Suite
    struct Test {
        @Suite struct Get {}
    }
}

// MARK: - List.get(host:) Smoke

#if !os(Windows)

    extension Kernel.Socket.Address.Info.Test.Get {
        @Test
        func `get(host:) resolves localhost through the unified Kernel surface`()
            throws(Kernel.Socket.Address.Info.Error)
        {
            // Cross-platform contract — no #if at the call site, single call.
            // Resolves via /etc/hosts, so no external network is required.
            // POSIX: composes through the POSIX_Kernel_Socket_Address L3 slot
            // ([PLAT-ARCH-008e] empty-tier delegate over ISO 9945 getaddrinfo).
            let hints = Kernel.Socket.Address.Info.Hints()
            let list = try Kernel.Socket.Address.Info.List.get(
                host: "localhost",
                hints: hints
            )
            _ = consume list
        }
    }

#endif

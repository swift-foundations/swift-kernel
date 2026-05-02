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

// L3 Descriptor ↔ Event.ID conversions. Lives at L3 because the typed
// Kernel.Descriptor is L3-unified (typealiased per platform), while
// Kernel.Event.ID is L1 vocabulary.

@_spi(Internal) import Tagged_Primitives
@_spi(Syscall) public import POSIX_Kernel_Descriptor

extension Tagged where Tag == Kernel.Event, RawValue == UInt {
    /// Creates an identifier from a file descriptor.
    public init(descriptor: borrowing Kernel.Descriptor) {
        #if os(Windows)
            self.init(__unchecked: (), descriptor._rawValue)
        #else
            self.init(__unchecked: (), UInt(bitPattern: Int(descriptor._rawValue)))
        #endif
    }
}

// Reverse conversion `Descriptor?(_ id: Event.ID)` removed per
// `feedback_no_raw_descriptor_reconstruction`: a `~Copyable` `Descriptor`
// must not be reconstructed from a raw integer once the original wrapper
// has been consumed. Consumers that need to act on a descriptor obtained
// via an event must hold the original `Descriptor` (e.g., via a registered
// handle table) rather than rebuild it from `Event.ID.rawValue`.

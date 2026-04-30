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
@_spi(Syscall) public import ISO_9945_Core

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

extension Kernel.Descriptor {
    /// Creates a file descriptor from an event identifier, if valid.
    @_spi(Syscall)
    public init?(_ id: Kernel.Event.ID) {
        #if os(Windows)
            self.init(_rawValue: id.rawValue)
        #else
            guard id.rawValue <= UInt(Int32.max) else { return nil }
            self.init(_rawValue: Int32(id.rawValue))
        #endif
    }
}

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// Raw memory mapping syscall wrappers.
    ///
    /// Memory mapping allows files and anonymous memory to be mapped
    /// directly into the process address space for efficient I/O.
    ///
    /// This namespace provides policy-free syscall wrappers.
    /// Higher layers (swift-mmap, swift-io) build region management,
    /// lock coordination, and RAII semantics on top of these primitives.
    public enum Mmap {}
}

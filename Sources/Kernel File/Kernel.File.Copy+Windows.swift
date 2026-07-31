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

// `Kernel.File.Copy` is the one member of the copy/clone family that is not
// hoisted into kernel: `POSIX.Kernel.File.Copy` is still live at
// swift-posix, so declaring `Kernel.File.Copy` here would collide on every
// POSIX leg. On Windows the opposite is true — `Windows.Kernel.File` is a
// distinct policy enum whose per-member typealiases deliberately exclude the
// hoisted family, so the name has nothing to resolve to. This Windows-only
// alias unifies it onto the L2-canonical declaration, whose `Error` and
// `Options` mirror the ISO shapes case-for-case and field-for-field, so the
// shared algorithm in `Kernel.File.Copy.swift` compiles against either.
//
// Delete this file in favour of a real hoist once swift-posix retires
// `POSIX.Kernel.File.Copy`.

#if os(Windows)

    public import Windows_Kernel_File

    extension Kernel.File {
        /// File copy operations — Windows resolves to the L2-canonical home.
        public typealias Copy = Windows.`32`.Kernel.File.Copy
    }

#endif

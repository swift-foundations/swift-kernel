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

public import SystemPackage

extension Kernel {
    /// An owned, null-terminated platform string buffer.
    ///
    /// This type copies a `FilePath`'s platform string into Kernel-owned storage,
    /// enabling typed-throwing syscalls without existential error handling.
    /// The copy happens in a non-throwing closure, and typed-throwing operations
    /// occur outside the rethrows boundary.
    @usableFromInline
    internal struct PlatformString: ~Copyable {
        @usableFromInline
        let buffer: UnsafeMutableBufferPointer<CInterop.PlatformChar>

        @inlinable
        init(copying path: FilePath) {
            var length = 0
            path.withPlatformString { p in
                while p[length] != 0 { length += 1 }
            }
            let buf = UnsafeMutableBufferPointer<CInterop.PlatformChar>.allocate(capacity: length + 1)
            path.withPlatformString { p in
                for i in 0...length {
                    buf[i] = p[i]
                }
            }
            self.buffer = buf
        }

        @usableFromInline
        deinit {
            buffer.deallocate()
        }

        @inlinable
        var pointer: UnsafePointer<CInterop.PlatformChar> {
            UnsafePointer(buffer.baseAddress!)
        }
    }
}

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

import Kernel_Primitives

// MARK: - Swift.String from Kernel.Path

extension Swift.String {
    /// Creates a Swift string from a kernel path.
    ///
    /// On POSIX, interprets the path bytes as UTF-8.
    /// On Windows, interprets the path code units as UTF-16.
    @usableFromInline
    internal init(_ path: borrowing Kernel.Path) {
        #if os(Windows)
        self = unsafe path.withUnsafeCString { wideChars in
            unsafe Swift.String(decodingCString: wideChars, as: UTF16.self)
        }
        #else
        self = unsafe path.withUnsafeCString { cString in
            unsafe Swift.String(cString: cString)
        }
        #endif
    }
}

// MARK: - Swift.String from Kernel.Path.View

extension Swift.String {
    /// Creates a Swift string from a kernel path view.
    ///
    /// On POSIX, interprets the path bytes as UTF-8.
    /// On Windows, interprets the path code units as UTF-16.
    @usableFromInline
    internal init(_ view: borrowing Kernel.Path.View) {
        #if os(Windows)
        self = unsafe view.withUnsafePointer { wideChars in
            unsafe Swift.String(decodingCString: wideChars, as: UTF16.self)
        }
        #else
        self = unsafe view.withUnsafePointer { cString in
            unsafe Swift.String(cString: cString)
        }
        #endif
    }
}

// MARK: - Swift.String from Kernel.String

extension Swift.String {
    /// Creates a Swift string from a kernel string.
    ///
    /// On POSIX, interprets the string bytes as UTF-8.
    /// On Windows, interprets the string code units as UTF-16.
    internal init(_ string: borrowing Kernel.String) {
        #if os(Windows)
        self = unsafe string.withUnsafePointer { wideChars in
            unsafe Swift.String(decodingCString: wideChars, as: UTF16.self)
        }
        #else
        self = unsafe string.withUnsafePointer { cString in
            unsafe Swift.String(cString: cString)
        }
        #endif
    }
}

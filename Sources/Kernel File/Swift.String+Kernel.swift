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

import Kernel_Path_Primitives
public import Kernel_String_Primitives
internal import String_Primitives

// MARK: - Swift.String from Kernel.Path

extension Swift.String {
    /// Creates a Swift string from a kernel path.
    ///
    /// On POSIX, interprets the path bytes as UTF-8.
    /// On Windows, interprets the path code units as UTF-16.
    @inlinable
    public init(_ path: borrowing Kernel.Path) {
        #if os(Windows)
        self = unsafe Swift.String(decodingCString: path.view.pointer, as: UTF16.self)
        #else
        self = unsafe Swift.String(cString: path.view.pointer)
        #endif
    }
}

// MARK: - Swift.String from Kernel.Path.View

extension Swift.String {
    /// Creates a Swift string from a kernel path view.
    ///
    /// On POSIX, interprets the path bytes as UTF-8.
    /// On Windows, interprets the path code units as UTF-16.
    @inlinable
    public init(_ view: borrowing Kernel.Path.View) {
        #if os(Windows)
        self = unsafe Swift.String(decodingCString: view.pointer, as: UTF16.self)
        #else
        self = unsafe Swift.String(cString: view.pointer)
        #endif
    }
}

// MARK: - Swift.String from Kernel.String

extension Swift.String {
    /// Creates a Swift string from a kernel string.
    ///
    /// On POSIX, interprets the string bytes as UTF-8.
    /// On Windows, interprets the string code units as UTF-16.
    public init(_ string: borrowing Kernel.String) {
        #if os(Windows)
        self = unsafe Swift.String(decodingCString: string.view.pointer, as: UTF16.self)
        #else
        self = unsafe Swift.String(cString: string.view.pointer)
        #endif
    }
}

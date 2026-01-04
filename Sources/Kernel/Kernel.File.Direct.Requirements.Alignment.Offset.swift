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

public import Binary

extension Kernel.File.Direct.Requirements.Alignment {
    /// Accessor for offset alignment validation.
    public struct Offset: Sendable {
        let alignment: Kernel.File.Direct.Requirements.Alignment

        /// Validates that a file offset is properly aligned.
        ///
        /// - Parameter offset: The file offset to validate.
        /// - Returns: `true` if the offset is a multiple of `offsetAlignment`.
        public func isAligned(_ offset: Int64) -> Bool {
            alignment.offsetAlignment.isAligned(offset)
        }
    }

    /// Accessor for offset alignment validation.
    public var offset: Offset { Offset(alignment: self) }
}

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

extension Kernel.File.Direct.Requirements.Alignment {
    /// Accessor for length validation.
    public struct Length: Sendable {
        let alignment: Kernel.File.Direct.Requirements.Alignment

        /// Validates that an I/O length is a valid multiple.
        ///
        /// - Parameter length: The transfer length to validate.
        /// - Returns: `true` if the length is a multiple of `lengthMultiple`.
        public func isValid(_ length: Int) -> Bool {
            length % alignment.lengthMultiple == 0
        }
    }

    /// Accessor for length validation.
    public var length: Length { Length(alignment: self) }
}

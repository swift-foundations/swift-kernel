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

extension Kernel.File.Direct.Requirements {
    /// Concrete alignment values for Direct I/O.
    public struct Alignment: Sendable, Equatable {
        /// Required alignment for buffer memory addresses.
        ///
        /// The buffer pointer passed to read/write must have an address
        /// that is a multiple of this value.
        ///
        /// Typical values: 512 (legacy), 4096 (modern SSDs/NVMe).
        public let bufferAlignment: Int

        /// Required alignment for file offsets.
        ///
        /// The file position for read/write operations must be a multiple
        /// of this value.
        ///
        /// Usually matches `bufferAlignment` but may differ on some systems.
        public let offsetAlignment: Int

        /// Required multiple for I/O transfer lengths.
        ///
        /// The number of bytes read/written must be a multiple of this value.
        /// Partial sector I/O is not allowed in Direct mode.
        ///
        /// Usually matches `bufferAlignment`.
        public let lengthMultiple: Int

        public init(
            bufferAlignment: Int,
            offsetAlignment: Int,
            lengthMultiple: Int
        ) {
            self.bufferAlignment = bufferAlignment
            self.offsetAlignment = offsetAlignment
            self.lengthMultiple = lengthMultiple
        }

        /// Creates alignment with a single value for all requirements.
        ///
        /// Use when buffer, offset, and length all share the same alignment.
        public init(uniform alignment: Int) {
            self.bufferAlignment = alignment
            self.offsetAlignment = alignment
            self.lengthMultiple = alignment
        }
    }
}

// MARK: - Validation

extension Kernel.File.Direct.Requirements.Alignment {
    /// Validates all alignment requirements for an I/O operation.
    ///
    /// - Parameters:
    ///   - bufferAddress: The buffer address.
    ///   - fileOffset: The file offset.
    ///   - transferLength: The transfer length.
    /// - Returns: The first validation failure, or `nil` if all pass.
    public func validate(
        buffer bufferAddress: UnsafeRawPointer,
        offset fileOffset: Int64,
        length transferLength: Int
    ) -> Kernel.File.Direct.Error? {
        if !buffer.isAligned(bufferAddress) {
            return .misalignedBuffer(
                address: Int(bitPattern: bufferAddress),
                required: bufferAlignment
            )
        }
        if !offset.isAligned(fileOffset) {
            return .misalignedOffset(
                offset: fileOffset,
                required: offsetAlignment
            )
        }
        if !length.isValid(transferLength) {
            return .invalidLength(
                length: transferLength,
                requiredMultiple: lengthMultiple
            )
        }
        return nil
    }
}

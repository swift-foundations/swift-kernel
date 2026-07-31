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

// MARK: - Direct-flavored opening path (kernel-hoisted vocabulary)
//
// `ISO_9945.Kernel.File.Handle.init(descriptor:direct:requirements:)` still
// takes the pre-hoist `ISO_9945.Kernel.File.Direct` vocabulary: spec-pure
// iso-9945 cannot reference kernel's hoisted L3 vocabulary, and the purge
// that would delete the pre-hoist types (swift-iso/swift-iso-9945#65) has
// not landed. Ruled routing puts the bridge kernel-side, since kernel
// already depends on posix and a reverse edge would cycle:
// https://github.com/swift-foundations/swift-posix/issues/6#issuecomment-5139756444
//
// This extension gives `Kernel.File.Open` an opening path typed entirely in
// kernel's hoisted `Kernel.File.Direct` vocabulary, delegating to the
// existing iso-9945 initializer. The vocabulary bridge below is a 1:1
// structural transliteration (both sides mirror each other case-for-case,
// field-for-field) rather than a semantic choice, and is deleted once #65
// lands and the iso-9945 initializer itself takes the hoisted types.

extension Kernel.File.Handle {
    /// Creates a handle from a descriptor with Direct I/O state, typed in
    /// kernel's hoisted `Kernel.File.Direct` vocabulary.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor (ownership transferred).
    ///   - direct: The resolved Direct I/O mode.
    ///   - requirements: The alignment requirements.
    public init(
        descriptor: consuming Kernel.Descriptor,
        direct: Kernel.File.Direct.Mode.Resolved,
        requirements: Kernel.File.Direct.Requirements
    ) {
        self.init(
            descriptor: descriptor,
            direct: direct.legacy,
            requirements: requirements.legacy
        )
    }
}

// MARK: - Vocabulary Bridge (kernel-hoisted -> pre-hoist iso-9945, pending #65)

extension Kernel.File.Direct.Mode.Resolved {
    fileprivate var legacy: ISO_9945.Kernel.File.Direct.Mode.Resolved {
        switch self {
        case .direct:
            return .direct

        case .uncached:
            return .uncached

        case .buffered:
            return .buffered
        }
    }
}

extension Kernel.File.Direct.Requirements {
    fileprivate var legacy: ISO_9945.Kernel.File.Direct.Requirements {
        switch self {
        case .known(let alignment):
            return .known(alignment.legacy)

        case .unknown(let reason):
            return .unknown(reason: reason.legacy)
        }
    }
}

extension Kernel.File.Direct.Requirements.Alignment {
    fileprivate var legacy: ISO_9945.Kernel.File.Direct.Requirements.Alignment {
        .init(
            bufferAlignment: bufferAlignment,
            offsetAlignment: offsetAlignment,
            lengthMultiple: lengthMultiple
        )
    }
}

extension Kernel.File.Direct.Requirements.Reason {
    fileprivate var legacy: ISO_9945.Kernel.File.Direct.Requirements.Reason {
        switch self {
        case .platformUnsupported:
            return .platformUnsupported

        case .sectorSizeUndetermined:
            return .sectorSizeUndetermined

        case .filesystemUnsupported:
            return .filesystemUnsupported

        case .invalidHandle:
            return .invalidHandle
        }
    }
}

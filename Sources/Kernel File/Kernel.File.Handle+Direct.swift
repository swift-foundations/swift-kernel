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
// The platform `Kernel.File.Handle.init(descriptor:direct:requirements:)`
// still takes its own pre-hoist Direct vocabulary: a spec-pure platform
// standard cannot reference kernel's hoisted L3 vocabulary, and the purge
// that would delete the pre-hoist types (swift-iso/swift-iso-9945#65) has
// not landed. Ruled routing puts the bridge kernel-side, since kernel
// already depends on the platform layer and a reverse edge would cycle:
// https://github.com/swift-foundations/swift-posix/issues/6#issuecomment-5139756444
//
// This extension gives `Kernel.File.Open` an opening path typed entirely in
// kernel's hoisted `Kernel.File.Direct` vocabulary. The delegated-to
// initializer supplies the contextual type for every argument below, so each
// platform value is written as a leading-dot member and no platform
// vocabulary is named in this file — which is also what lets this same
// source compile on Windows against `Windows.\`32\`.Kernel.File.Handle`.
// The case and field sets match kernel's one-for-one, so what follows is a
// structural transliteration rather than a semantic choice.

extension Kernel.File.Handle {
    /// Creates a handle from a descriptor with Direct I/O state, typed in
    /// kernel's hoisted `Kernel.File.Direct` vocabulary.
    ///
    /// The argument label is `mode:` rather than `direct:` so this entry
    /// point does not overload the platform initializer it delegates to:
    /// with identical labels every leading-dot argument below stays viable
    /// for both candidates, and the delegation becomes ambiguous with
    /// itself.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor (ownership transferred).
    ///   - mode: The resolved Direct I/O mode.
    ///   - requirements: The alignment requirements.
    public init(
        descriptor: consuming Kernel.Descriptor,
        mode direct: Kernel.File.Direct.Mode.Resolved,
        requirements: Kernel.File.Direct.Requirements
    ) {
        // Each transliterating closure sits directly in an argument position
        // so the delegated-to initializer pins its result type. Nesting one
        // inside another leaves the inner leading-dot members ambiguous
        // between kernel's vocabulary and the platform's, which is why the
        // requirements cases are switched here rather than inline.
        switch requirements {
        case .known(let alignment):
            self.init(
                descriptor: descriptor,
                direct: {
                    switch direct {
                    case .direct: .direct

                    case .uncached: .uncached

                    case .buffered: .buffered
                    }
                }(),
                requirements: .known(
                    .init(
                        bufferAlignment: alignment.bufferAlignment,
                        offsetAlignment: alignment.offsetAlignment,
                        lengthMultiple: alignment.lengthMultiple
                    )
                )
            )

        case .unknown(let reason):
            self.init(
                descriptor: descriptor,
                direct: {
                    switch direct {
                    case .direct: .direct

                    case .uncached: .uncached

                    case .buffered: .buffered
                    }
                }(),
                requirements: .unknown(
                    reason: {
                        switch reason {
                        case .platformUnsupported: .platformUnsupported

                        case .sectorSizeUndetermined: .sectorSizeUndetermined

                        case .filesystemUnsupported: .filesystemUnsupported

                        case .invalidHandle: .invalidHandle
                        }
                    }()
                )
            )
        }
    }
}

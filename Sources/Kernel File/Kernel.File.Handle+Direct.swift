extension Kernel.File.Handle {

    public init(
        descriptor: consuming Kernel.Descriptor,
        mode direct: Kernel.File.Direct.Mode.Resolved,
        requirements: Kernel.File.Direct.Requirements
    ) {

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

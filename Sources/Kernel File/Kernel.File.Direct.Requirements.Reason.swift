extension Kernel.File.Direct.Requirements {

    public enum Reason: Sendable, Equatable, CustomStringConvertible {

        case platformUnsupported

        case sectorSizeUndetermined

        case filesystemUnsupported

        case invalidHandle
    }
}

extension Kernel.File.Direct.Requirements.Reason {
    public var description: Swift.String {
        switch self {
        case .platformUnsupported:
            return "Platform does not support strict Direct I/O"

        case .sectorSizeUndetermined:
            return "Could not determine sector size"

        case .filesystemUnsupported:
            return "Filesystem does not support Direct I/O"

        case .invalidHandle:
            return "Invalid file handle"
        }
    }
}

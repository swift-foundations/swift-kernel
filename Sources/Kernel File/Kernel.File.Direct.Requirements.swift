public import Path_Primitives

extension Kernel.File.Direct {

    public enum Requirements: Sendable, Equatable {

        case known(Alignment)

        case unknown(reason: Reason)
    }
}

extension Kernel.File.Direct.Requirements {

    public init(_ path: borrowing Path.Borrowed) {
        #if os(macOS)
            self = .unknown(reason: .platformUnsupported)
        #elseif os(Linux)
            self = .unknown(reason: .sectorSizeUndetermined)
        #elseif os(Windows)
            self = .known(Alignment(uniform: .`4096`))
        #else
            self = .unknown(reason: .platformUnsupported)
        #endif
    }
}

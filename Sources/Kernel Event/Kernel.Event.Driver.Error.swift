#if !os(Windows)
    extension Kernel.Event.Driver {

        public enum Error: Swift.Error, Sendable, Equatable {

            case platform(Error_Primitives.Error.Code)

            case invalidDescriptor

            case notRegistered

            case unsupportedPlatform
        }
    }
#endif

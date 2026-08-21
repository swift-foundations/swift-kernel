extension Kernel.Completion {

    public enum Error: Swift.Error, Sendable, Equatable {

        case platform(Error_Primitives.Error.Code)

        case submissionQueueFull

        case invalidDescriptor

        case unsupportedPlatform
    }
}

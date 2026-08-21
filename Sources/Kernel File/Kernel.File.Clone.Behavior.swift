extension Kernel.File.Clone {

    public enum Behavior: Sendable, Equatable {

        case reflinkOrFail

        case reflinkOrCopy

        case copyOnly
    }
}

extension Kernel.Thread.Affinity {

    public enum Failure: Sendable, Equatable {

        case ignore

        case report

        case fatal
    }
}

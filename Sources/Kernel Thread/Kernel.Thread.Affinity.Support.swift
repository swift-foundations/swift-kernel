extension Kernel.Thread.Affinity {

    public enum Support: Sendable, Equatable {

        case none

        case advisory

        case enforced
    }
}

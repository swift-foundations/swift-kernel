extension Kernel.Thread.Affinity {

    public enum Kind: Sendable, Equatable {

        case any

        case cores(Set<Int>)

        case numaNode(Int)
    }
}

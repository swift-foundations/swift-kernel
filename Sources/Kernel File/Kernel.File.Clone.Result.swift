extension Kernel.File.Clone {

    public enum Result: Sendable, Equatable {

        case reflinked

        case copied
    }
}

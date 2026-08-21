public import Error_Primitives

extension Kernel.Thread.Affinity {

    public enum Error: Swift.Error, Sendable, Equatable, Hashable {

        case unsupported

        case invalidNode(Int)

        case tooManyCPUs

        case platform(Error_Primitives.Error.Code)
    }
}

extension Kernel.Thread.Affinity.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .unsupported:
            return "thread affinity not supported on this platform"

        case .invalidNode(let id):
            return "invalid NUMA node: \(id)"

        case .tooManyCPUs:
            return "CPU set exceeds platform capacity"

        case .platform(let code):
            return "thread affinity failed: \(code)"
        }
    }
}

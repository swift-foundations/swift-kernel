#if os(Linux)
    internal import Linux_Kernel_System_Standard
    internal import System_Primitives
#elseif os(Windows)
    internal import System_Primitives
    internal import Windows_32_Kernel_System
    internal import Windows_32_Kernel_Thread
#endif

extension Kernel.Thread.Affinity {

    public static var support: Support {
        #if os(Linux)
            .enforced
        #elseif os(Windows)
            .enforced
        #else
            .none
        #endif
    }

    public static func apply(
        _ affinity: Kernel.Thread.Affinity
    ) throws(Kernel.Thread.Affinity.Error) {
        switch affinity.kind {
        case .any:
            return

        case .cores(let cores):
            try pin(to: cores)

        case .numaNode(let node):
            try pin(to: cpus(of: node))
        }
    }
}

extension Kernel.Thread.Affinity {

    private static func pin(
        to cores: Set<Int>
    ) throws(Kernel.Thread.Affinity.Error) {
        #if os(Linux)
            do throws(Linux.Kernel.Thread.Affinity.Error) {
                try Linux.Kernel.Thread.Affinity.setMask(cores: cores)
            } catch {
                switch error {
                case .platform(let code):
                    throw .platform(code)
                }
            }

        #elseif os(Windows)
            do throws(Windows.`32`.Kernel.Thread.Affinity.Error) {
                try Windows.`32`.Kernel.Thread.Affinity.setMask(cores: cores)
            } catch {
                switch error {
                case .unsupported:
                    throw .unsupported

                case .invalidNode(let node):
                    throw .invalidNode(node)

                case .tooManyCPUs:
                    throw .tooManyCPUs

                case .platform(let code):
                    throw .platform(code)
                }
            }

        #else
            throw .unsupported
        #endif
    }

    private static func cpus(
        of node: Int
    ) throws(Kernel.Thread.Affinity.Error) -> Set<Int> {
        #if os(Linux) || os(Windows)
            guard case .nonUniform(let nodes) = System.Topology.NUMA.discover(),
                let match = nodes.first(where: { $0.id == node })
            else {
                throw .invalidNode(node)
            }
            return match.cpus

        #else
            throw .unsupported
        #endif
    }
}

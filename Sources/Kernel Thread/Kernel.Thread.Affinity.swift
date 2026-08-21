extension Kernel.Thread {

    public struct Affinity: Sendable, Equatable {

        public let kind: Kind

        public init(kind: Kind) {
            self.kind = kind
        }
    }
}

extension Kernel.Thread.Affinity {

    public static let any = Self(kind: .any)

    public static func cores(_ cores: some Swift.Sequence<Int>) -> Self {
        Self(kind: .cores(Set(cores)))
    }

    public static func numaNode(_ id: Int) -> Self {
        Self(kind: .numaNode(id))
    }
}

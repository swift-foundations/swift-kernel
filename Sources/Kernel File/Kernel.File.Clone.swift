public import Path_Primitives

extension Kernel.File {
    public enum Clone {}
}

extension Kernel.File.Clone.Capability {

    public static func probeDefault(at path: borrowing Path) -> Kernel.File.Clone.Capability {
        _ = path
        return .none
    }
}

extension Kernel.File.Clone {

    public enum Metadata {}
}

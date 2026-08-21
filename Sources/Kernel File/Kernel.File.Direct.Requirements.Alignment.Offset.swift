public import Memory_Primitives

extension Kernel.File.Direct.Requirements.Alignment {

    public struct Offset: Sendable {
        let alignment: Kernel.File.Direct.Requirements.Alignment
    }

    public var offset: Offset { Offset(alignment: self) }
}

extension Kernel.File.Direct.Requirements.Alignment.Offset {

    public func isAligned(_ offset: Kernel.File.Offset) -> Bool {
        let mask: Int64 = alignment.offsetAlignment.mask()
        return offset.underlying & mask == 0
    }
}

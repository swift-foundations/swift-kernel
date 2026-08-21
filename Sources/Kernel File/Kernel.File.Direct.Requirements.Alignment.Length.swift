public import Memory_Primitives

extension Kernel.File.Direct.Requirements.Alignment {

    public struct Length: Sendable {
        let alignment: Kernel.File.Direct.Requirements.Alignment
    }

    public var length: Length { Length(alignment: self) }
}

extension Kernel.File.Direct.Requirements.Alignment.Length {

    public func isValid(_ length: Kernel.File.Size) -> Bool {
        let mask: Int64 = alignment.lengthMultiple.mask()
        return length.underlying & mask == 0
    }
}

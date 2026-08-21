public import Memory_Primitives

extension Kernel.File.Direct.Requirements.Alignment {

    public struct Buffer: Sendable {
        let alignment: Kernel.File.Direct.Requirements.Alignment
    }

    public var buffer: Buffer { Buffer(alignment: self) }
}

extension Kernel.File.Direct.Requirements.Alignment.Buffer {

    public func isAligned(_ address: Memory.Address) -> Bool {
        alignment.bufferAlignment.isAligned(address.bitPattern)
    }
}

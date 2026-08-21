public import Error_Primitives
public import Memory_Primitives

extension Kernel.File.Direct {

    public enum Error: Swift.Error, Sendable, Equatable {

        case notSupported

        case misalignedBuffer(address: Memory.Address, required: Memory.Alignment)

        case misalignedOffset(offset: Int64, required: Memory.Alignment)

        case invalidLength(length: Int, requiredMultiple: Memory.Alignment)

        case modeChange

        case invalidHandle

        case platform(code: Error_Primitives.Error.Code, operation: Operation)
    }
}

extension Kernel.File.Direct.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .notSupported:
            return "Direct I/O not supported"

        case .misalignedBuffer(let address, let required):
            return "Buffer address \(address) not aligned to \(required)"

        case .misalignedOffset(let offset, let required):
            return "File offset \(offset) not aligned to \(required) bytes"

        case .invalidLength(let length, let requiredMultiple):
            return "Length \(length) is not a multiple of \(requiredMultiple)"

        case .modeChange:
            return "Failed to change cache mode"

        case .invalidHandle:
            return "Invalid file handle"

        case .platform(let code, let operation):
            return "Platform error \(code) during \(operation)"
        }
    }
}

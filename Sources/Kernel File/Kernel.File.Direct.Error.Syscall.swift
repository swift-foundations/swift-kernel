public import Error_Primitives

extension Kernel.File.Direct.Error {

    public enum Syscall: Swift.Error, Sendable, Equatable {

        case platform(code: Error_Primitives.Error.Code, operation: Operation)

        case invalidDescriptor(operation: Operation)

        case alignmentViolation(operation: Operation)

        case notSupported(operation: Operation)
    }
}

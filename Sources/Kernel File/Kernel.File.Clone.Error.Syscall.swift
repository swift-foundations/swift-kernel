public import Error_Primitives

extension Kernel.File.Clone.Error {

    public enum Syscall: Swift.Error, Sendable {

        case platform(code: Error_Primitives.Error.Code, operation: Operation)

        case notSupported(operation: Operation)
    }
}

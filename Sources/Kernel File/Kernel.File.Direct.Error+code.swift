public import Error_Primitives

extension Kernel.File.Direct.Error {

    public init(from syscall: Syscall) {
        switch syscall {
        case .invalidDescriptor:
            self = .invalidHandle

        case .alignmentViolation(let operation):
            self = .platform(code: .posix(-1), operation: operation)

        case .notSupported:
            self = .notSupported

        case .platform(let code, let operation):
            self.init(code: code, operation: operation)
        }
    }

    @usableFromInline
    internal init(code: Error_Primitives.Error.Code, operation: Operation) {
        #if os(Windows)
            self = .platform(code: code, operation: operation)
        #else
            switch code {
            case _ where code == .POSIX.EINVAL:
                self = .platform(code: code, operation: operation)

            case _ where code == .POSIX.EBADF:
                self = .invalidHandle

            case _ where Error_Primitives.Error.Code.POSIX.isENOTSUP(code):
                self = .notSupported

            default:
                self = .platform(code: code, operation: operation)
            }
        #endif
    }
}

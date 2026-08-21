public import Error_Primitives

extension Kernel.File.Clone.Error {

    public init(from syscall: Syscall) {
        switch syscall {
        case .notSupported:
            self = .notSupported

        case .platform(let code, let operation):
            self.init(code: code, operation: operation)
        }
    }

    public init(code: Error_Primitives.Error.Code, operation: Operation) {
        #if os(Windows)
            self = .platform(code: code, operation: operation)
        #else
            switch code {
            case _ where code == .POSIX.ENOENT:
                self = .sourceNotFound

            case _ where code == .POSIX.EEXIST:
                self = .destinationExists

            case _ where code == .POSIX.EACCES,
                _ where code == .POSIX.EPERM:
                self = .permissionDenied

            case _ where code == .POSIX.EXDEV:
                self = .crossDevice

            case _ where code == .POSIX.EISDIR:
                self = .isDirectory

            case _ where Error_Primitives.Error.Code.POSIX.isENOTSUP(code):
                self = .notSupported

            default:
                self = .platform(code: code, operation: operation)
            }
        #endif
    }
}

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public import POSIX_Kernel_Descriptor
#endif

extension Kernel {

    public enum Failure: Swift.Error, Sendable, Equatable {

        case path(Path.Resolution.Error)

        case handle(Kernel.Descriptor.Validity.Error)

        case io(Kernel.IO.Error)

        case lock(Kernel.Lock.Error)

        case memory(Memory.Allocation.Error)

        case permission(Kernel.Permission.Error)

        case space(Kernel.Storage.Error)

        #if !os(Windows)

            case signal(Kernel.Signal.Error)
        #endif

        case blocking(Kernel.IO.Blocking.Error)

        case platform(Error_Primitives.Error)
    }
}

extension Kernel.Failure: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .path(let error):
            return "path: \(error)"

        case .handle(let error):
            return "handle: \(error)"

        case .io(let error):
            return "io: \(error)"

        case .lock(let error):
            return "lock: \(error)"

        case .memory(let error):
            return "memory: \(error)"

        case .permission(let error):
            return "permission: \(error)"

        case .space(let error):
            return "space: \(error)"

        #if !os(Windows)
            case .signal(let error):
                return "signal: \(error)"
        #endif

        case .blocking(let error):
            return "blocking: \(error)"

        case .platform(let error):
            return "\(error)"
        }
    }
}

extension Kernel.Failure {
    public init?(
        _ code: Error_Primitives.Error.Code
    ) {

        if let e = Path.Resolution.Error(code: code) {
            self = .path(e)
            return
        }
        if let e = Kernel.Permission.Error(code: code) {
            self = .permission(e)
            return
        }
        if let e = Kernel.Descriptor.Validity.Error(code: code) {
            self = .handle(e)
            return
        }
        #if !os(Windows)
            if let e = Kernel.Signal.Error(code: code) {
                self = .signal(e)
                return
            }
        #endif
        if let e = Kernel.IO.Blocking.Error(code: code) {
            self = .blocking(e)
            return
        }
        if let e = Kernel.Storage.Error(code: code) {
            self = .space(e)
            return
        }
        if let e = Memory.Allocation.Error(code: code) {
            self = .memory(e)
            return
        }
        if let e = Kernel.IO.Error(code: code) {
            self = .io(e)
            return
        }
        if let e = Kernel.Lock.Error(code: code) {
            self = .lock(e)
            return
        }
        return nil
    }
}

extension Kernel.Failure {

    public static func message(for code: Error_Primitives.Error.Code) -> Swift.String? {
        #if os(Windows)
            code.win32Message
        #else
            code.posixMessage
        #endif
    }
}

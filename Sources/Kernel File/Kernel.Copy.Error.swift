extension Kernel.Copy {

    public enum Error: Swift.Error, Sendable, Equatable, Hashable {

        case invalidDescriptor

        case crossDevice

        case unsupported

        case noSpace

        case io

        case permissionDenied

        case exists

        case notFound
    }
}

extension Kernel.Copy.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .invalidDescriptor: return "invalid file descriptor"
        case .crossDevice: return "cross-device copy not supported"
        case .unsupported: return "operation not supported"
        case .noSpace: return "no space left on device"
        case .io: return "I/O error"
        case .permissionDenied: return "permission denied"
        case .exists: return "destination already exists"
        case .notFound: return "source not found"
        }
    }
}

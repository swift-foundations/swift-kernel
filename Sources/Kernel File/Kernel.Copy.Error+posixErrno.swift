#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

    #if canImport(Darwin)
        internal import Darwin
    #elseif canImport(Glibc)
        internal import Glibc
    #elseif canImport(Musl)
        internal import Musl
    #endif

    extension Kernel.Copy.Error {

        public init(posixErrno: Int32) {
            switch posixErrno {
            case EBADF:
                self = .invalidDescriptor

            case EXDEV:
                self = .crossDevice

            case ENOSPC:
                self = .noSpace

            case EIO:
                self = .io

            case EACCES, EPERM:
                self = .permissionDenied

            case ENOENT:
                self = .notFound

            case EEXIST:
                self = .exists

            case EINVAL, ENOTSUP:
                self = .unsupported

            default:
                self = .unsupported
            }
        }
    }

#endif

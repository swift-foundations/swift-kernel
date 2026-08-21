#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public import POSIX_Kernel_Descriptor
#endif

extension Kernel.Completion {

    public struct Notification: ~Copyable {

        public let descriptor: Kernel.Descriptor

        public init(descriptor: consuming Kernel.Descriptor) {
            self.descriptor = descriptor
        }
    }
}

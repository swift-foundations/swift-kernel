#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

    extension Kernel.File.Flush {

        @inlinable
        public static func data(_ descriptor: borrowing Kernel.Descriptor) throws(Error) {
            try ISO_9945.Kernel.File.Flush.data(descriptor)
        }

    }

#endif

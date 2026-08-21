#if os(Windows)

    public import Path_Primitives

    extension Kernel.File.Flush {

        @inlinable
        public static func data(_ descriptor: borrowing Kernel.Descriptor) throws(Error) {
            try Windows.`32`.Kernel.File.Flush.flush(descriptor)
        }

        @inlinable
        public static func directory(path: borrowing Path.Borrowed) throws(Error) {
            _ = path
        }
    }

#endif

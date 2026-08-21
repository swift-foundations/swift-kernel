#if os(Windows)

    public import Windows_32_Kernel_Thread
    public import Windows_Kernel_Thread

    extension Kernel.Thread {

        @inlinable
        public static func create(
            _ body: @escaping @Sendable () -> Void
        ) throws(Kernel.Thread.Error) -> Kernel.Thread.Handle {
            try Windows.`32`.Kernel.Thread.create(body)
        }

        @inlinable
        public static func yield() {
            Windows.`32`.Kernel.Thread.yield()
        }
    }

#endif

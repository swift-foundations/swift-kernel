#if os(Windows)

    public import Windows_Kernel_File

    extension Kernel.File {

        public typealias Copy = Windows.`32`.Kernel.File.Copy
    }

#endif

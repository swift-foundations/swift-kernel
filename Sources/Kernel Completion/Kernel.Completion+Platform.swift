extension Kernel.Completion {

    public static func platform() throws(Error) -> Kernel.Completion {
        #if os(Linux)
            try .iouring()
        #else
            throw .unsupportedPlatform
        #endif
    }
}

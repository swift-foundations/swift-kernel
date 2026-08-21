extension System.Processor {

    @inlinable
    public static var count: System.Processor.Count {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD)
            System.processorCount
        #elseif os(Windows)
            System.processorCount
        #else
            fatalError("System.Processor.count: unsupported platform")
        #endif
    }
}

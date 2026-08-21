#if os(Linux) || os(Android) || os(OpenBSD) || os(Windows)
    extension System.Processor.Physical {

        @inlinable
        public static var count: System.Processor.Count {
            System.processorCount
        }
    }
#endif

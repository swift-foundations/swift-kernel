#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD) || os(Windows)

    extension Kernel.Lock.Acquire {

        public static func timeout(_ duration: Duration) -> Self {
            .deadline(Clock.Continuous.now.advanced(by: duration))
        }
    }

#endif

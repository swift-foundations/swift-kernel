#if !os(Windows)
    extension Kernel.Event.Source {

        public static func platform() throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
                try .kqueue()
            #elseif os(Linux)
                try .epoll()
            #else

                throw .unsupportedPlatform
            #endif
        }
    }
#endif

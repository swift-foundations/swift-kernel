#if os(Linux)

    extension Kernel.Completion.Submission.Flags {

        public static let bufferSelect = Self(rawValue: 1 << 0)

        public static let linked = Self(rawValue: 1 << 1)

        public static let drain = Self(rawValue: 1 << 2)

        public static let fixedFile = Self(rawValue: 1 << 3)
    }

#endif

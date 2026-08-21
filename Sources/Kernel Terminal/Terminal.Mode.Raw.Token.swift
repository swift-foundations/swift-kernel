#if !os(Windows)
    @_spi(Syscall) import POSIX_Kernel_Terminal
#endif

extension Terminal.Mode.Raw {

    public struct Token: ~Copyable, Sendable {

        public let stream: Terminal.Stream

        public let previous: Previous

        public var restored: Bool = false

        public init(stream: Terminal.Stream, previous: Previous) {
            self.stream = stream
            self.previous = previous
        }
    }
}

extension Terminal.Mode.Raw.Token {

    public enum Previous: Sendable {
        #if !os(Windows)
            case posix(ISO_9945.Kernel.Termios.Attributes)
        #endif

        #if os(Windows)
            case windows(UInt32)
        #endif
    }
}

#if !os(Windows)

    extension Terminal.Mode.Raw {

        public func enter() throws(Terminal.Error) -> Token {
            do throws(Error_Primitives.Error) {
                let original = try ISO_9945.Kernel.Termios.Attributes.get(fd: stream.rawValue)
                let raw = original.withRaw()
                try ISO_9945.Kernel.Termios.Attributes.set(raw, fd: stream.rawValue)
                return Token(stream: stream, previous: .posix(original))
            } catch {
                throw Terminal.Error(operation: .enterRaw, underlying: .kernel(error))
            }
        }
    }

    extension Terminal.Mode.Raw.Token {

        public mutating func restore() throws(Terminal.Error) {
            guard !restored else { return }
            guard case .posix(let attrs) = previous else {
                throw Terminal.Error(operation: .exitRaw, underlying: .unsupported)
            }
            do throws(Error_Primitives.Error) {
                try ISO_9945.Kernel.Termios.Attributes.set(attrs, fd: stream.rawValue)
                restored = true
            } catch let error {
                throw Terminal.Error(operation: .exitRaw, underlying: .kernel(error))
            }
        }
    }

#endif

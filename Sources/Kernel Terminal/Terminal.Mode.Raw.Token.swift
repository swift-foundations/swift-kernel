// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Cycle 22 relocation: Token + Previous moved from L1 swift-terminal-primitives
// to L3 swift-kernel because Previous's `.posix` case carries
// `Kernel.Termios.Attributes` (relocated to L2 iso-9945 in Cycle 22).
// L1 cannot reference an L2 type. The L3 home composes both L1
// `Terminal.Mode.Raw` namespace and the L2 typed Termios.Attributes.

#if !os(Windows)
    @_spi(Syscall) import POSIX_Kernel_Terminal
#endif

extension Terminal.Mode.Raw {
    /// Token for restoring terminal mode after entering raw mode.
    ///
    /// Move-only type that ensures the previous terminal mode is restored
    /// either explicitly via ``restore()`` or implicitly when the token
    /// goes out of scope (deinit-managed by the platform layer).
    public struct Token: ~Copyable, Sendable {
        /// The stream this token is for.
        public let stream: Terminal.Stream
        /// The previous terminal state (platform-specific).
        public let previous: Previous
        /// Whether the mode has been restored.
        public var restored: Bool = false

        /// Creates a token with the given stream and previous state.
        public init(stream: Terminal.Stream, previous: Previous) {
            self.stream = stream
            self.previous = previous
        }
    }
}

extension Terminal.Mode.Raw.Token {
    /// Previous terminal state (platform-specific).
    public enum Previous: Sendable {
        #if !os(Windows)
            case posix(ISO_9945.Kernel.Termios.Attributes)
        #endif

        #if os(Windows)
            case windows(UInt32)  // Console mode flags
        #endif
    }
}

// MARK: - Raw Mode Enter / Restore (POSIX)

#if !os(Windows)

    extension Terminal.Mode.Raw {
        /// Enter raw mode on this stream (POSIX).
        ///
        /// Captures the current termios state, applies raw flags via
        /// `Termios.Attributes.withRaw()`, and returns a token that
        /// preserves the previous state for restoration.
        ///
        /// - Returns: A token to restore the previous terminal mode.
        /// - Throws: ``Terminal.Error`` if entering raw mode fails.
        public func enter() throws(Terminal.Error) -> Token {
            do {
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
        /// Restore the previous terminal mode.
        ///
        /// - Throws: ``Terminal.Error`` if restoration fails.
        public mutating func restore() throws(Terminal.Error) {
            guard !restored else { return }
            guard case .posix(let attrs) = previous else {
                throw Terminal.Error(operation: .exitRaw, underlying: .unsupported)
            }
            do {
                try ISO_9945.Kernel.Termios.Attributes.set(attrs, fd: stream.rawValue)
                restored = true
            } catch let error {
                throw Terminal.Error(operation: .exitRaw, underlying: .kernel(error))
            }
        }
    }

#endif

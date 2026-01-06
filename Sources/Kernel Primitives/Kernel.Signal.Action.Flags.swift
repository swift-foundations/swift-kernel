// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if !os(Windows)

#if canImport(Darwin)
    public import Darwin
#elseif canImport(Glibc)
    public import Glibc
#elseif canImport(Musl)
    public import Musl
#endif

extension Kernel.Signal.Action {
    /// Signal action flags.
    ///
    /// These flags modify how signals are handled when delivered.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Restart interrupted syscalls automatically
    /// let config = Kernel.Signal.Action.Configuration(
    ///     handler: .custom(myHandler),
    ///     flags: .restart
    /// )
    ///
    /// // Use extended signal info
    /// let config = Kernel.Signal.Action.Configuration(
    ///     handler: .customInfo(myInfoHandler),
    ///     flags: [.restart, .sigInfo]  // sigInfo added automatically
    /// )
    /// ```
    public struct Flags: OptionSet, Sendable, Equatable, Hashable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Don't send `SIGCHLD` when children stop.
        ///
        /// - POSIX: `SA_NOCLDSTOP`
        public static let noChildStop = Self(rawValue: SA_NOCLDSTOP)

        /// Don't create zombie on child death.
        ///
        /// - POSIX: `SA_NOCLDWAIT`
        public static let noChildWait = Self(rawValue: SA_NOCLDWAIT)

        /// Reset handler to default after signal is caught.
        ///
        /// - POSIX: `SA_RESETHAND`
        public static let resetHandler = Self(rawValue: SA_RESETHAND)

        /// Restart interrupted syscalls automatically.
        ///
        /// - POSIX: `SA_RESTART`
        public static let restart = Self(rawValue: SA_RESTART)

        /// Use alternate signal stack (requires sigaltstack setup).
        ///
        /// - POSIX: `SA_ONSTACK`
        public static let onStack = Self(rawValue: SA_ONSTACK)

        /// Don't block signal while handler executes.
        ///
        /// - POSIX: `SA_NODEFER`
        public static let noDefer = Self(rawValue: SA_NODEFER)

        /// Use `sa_sigaction` handler instead of `sa_handler`.
        ///
        /// Required when using `.customInfo` handler. The `Configuration`
        /// initializer enforces this automatically.
        ///
        /// - POSIX: `SA_SIGINFO`
        public static let sigInfo = Self(rawValue: SA_SIGINFO)
    }
}

#endif

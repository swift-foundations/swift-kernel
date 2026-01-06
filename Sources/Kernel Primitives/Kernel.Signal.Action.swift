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
    /// Sets the signal action, returning the previous configuration.
    ///
    /// - Parameters:
    ///   - signal: The signal to configure.
    ///   - configuration: The new signal action configuration.
    /// - Returns: The previous signal action configuration.
    /// - Throws: `Error.action` on failure.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Install a custom handler
    /// let config = Configuration(handler: .custom(myHandler), flags: .restart)
    /// let previous = try Kernel.Signal.Action.set(signal: .user1, config)
    ///
    /// // Always restore on cleanup
    /// defer { _ = try? Kernel.Signal.Action.set(signal: .user1, previous) }
    /// ```
    @discardableResult
    @inlinable
    public static func set(
        signal: Kernel.Signal.Number,
        _ configuration: Configuration
    ) throws(Kernel.Signal.Error) -> Configuration {
        var newAction = sigaction()
        var oldAction = sigaction()

        configurationToSigaction(configuration, &newAction)

        guard sigaction(signal.rawValue, &newAction, &oldAction) == 0 else {
            throw .action(.captureErrno())
        }

        return sigactionToConfiguration(oldAction)
    }

    /// Gets the current signal action configuration.
    ///
    /// - Parameter signal: The signal to query.
    /// - Returns: The current signal action configuration.
    /// - Throws: `Error.action` on failure.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let config = try Kernel.Signal.Action.get(signal: .user1)
    /// switch config.handler {
    /// case .default: print("Using default action")
    /// case .ignore: print("Signal ignored")
    /// case .custom: print("Custom handler installed")
    /// case .customInfo: print("Custom handler with siginfo")
    /// }
    /// ```
    @inlinable
    public static func get(
        signal: Kernel.Signal.Number
    ) throws(Kernel.Signal.Error) -> Configuration {
        var action = sigaction()

        guard sigaction(signal.rawValue, nil, &action) == 0 else {
            throw .action(.captureErrno())
        }

        return sigactionToConfiguration(action)
    }
}

// MARK: - Internal Conversion Helpers

extension Kernel.Signal.Action {
    /// Converts a Configuration to a raw sigaction struct.
    @usableFromInline
    internal static func configurationToSigaction(
        _ configuration: Configuration,
        _ action: inout sigaction
    ) {
        // Set mask
        action.sa_mask = configuration.mask.storage

        // Set flags
        action.sa_flags = configuration.flags.rawValue

        // Set handler based on type
        #if canImport(Darwin)
            switch configuration.handler {
            case .default:
                action.__sigaction_u.__sa_handler = SIG_DFL
            case .ignore:
                action.__sigaction_u.__sa_handler = SIG_IGN
            case .custom(let handler):
                action.__sigaction_u.__sa_handler = handler
            case .customInfo(let handler):
                action.__sigaction_u.__sa_sigaction = handler
            }
        #else
            // Linux/Glibc/Musl
            switch configuration.handler {
            case .default:
                action.__sigaction_handler.sa_handler = SIG_DFL
            case .ignore:
                action.__sigaction_handler.sa_handler = SIG_IGN
            case .custom(let handler):
                action.__sigaction_handler.sa_handler = handler
            case .customInfo(let handler):
                action.__sigaction_handler.sa_sigaction = handler
            }
        #endif
    }

    /// Converts a raw sigaction struct to a Configuration.
    @usableFromInline
    internal static func sigactionToConfiguration(
        _ action: sigaction
    ) -> Configuration {
        let flags = Flags(rawValue: action.sa_flags)
        let mask = Kernel.Signal.Set(storage: action.sa_mask)

        // Determine handler type
        let handler: Handler

        #if canImport(Darwin)
            let handlerPtr = action.__sigaction_u.__sa_handler
            let sigactionPtr = action.__sigaction_u.__sa_sigaction
        #else
            let handlerPtr = action.__sigaction_handler.sa_handler
            let sigactionPtr = action.__sigaction_handler.sa_sigaction
        #endif

        if flags.contains(.sigInfo) {
            // SA_SIGINFO set, use sa_sigaction
            if let ptr = sigactionPtr {
                handler = .customInfo(ptr)
            } else {
                // Shouldn't happen, but fallback to default
                handler = .default
            }
        } else {
            // Check for special handler values using raw pointer comparison
            // SIG_DFL and SIG_IGN are special constants (typically 0 and 1)
            let handlerRaw = unsafeBitCast(handlerPtr, to: Int.self)
            let sigDflRaw = unsafeBitCast(SIG_DFL, to: Int.self)
            let sigIgnRaw = unsafeBitCast(SIG_IGN, to: Int.self)

            if handlerRaw == sigDflRaw {
                handler = .default
            } else if handlerRaw == sigIgnRaw {
                handler = .ignore
            } else if let ptr = handlerPtr {
                handler = .custom(ptr)
            } else {
                handler = .default
            }
        }

        return Configuration(handler: handler, mask: mask, flags: flags)
    }
}

#endif

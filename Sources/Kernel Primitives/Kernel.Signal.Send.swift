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

extension Kernel.Signal {
    /// Signal sending operations.
    public enum Send {}
}

extension Kernel.Signal.Send {
    /// Sends a signal to a process.
    ///
    /// - Parameters:
    ///   - signal: The signal to send.
    ///   - pid: The target process ID.
    /// - Throws: `Kernel.Signal.Error.send` on failure.
    ///
    /// ## Common Errors
    ///
    /// - `.noPermission` (EPERM): Caller lacks permission to send signal to target.
    /// - `.noSuchProcess` (ESRCH): No process with the specified PID exists.
    /// - `.invalidSignal` (EINVAL): Invalid signal number.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Send SIGTERM to a process
    /// try Kernel.Signal.Send.toProcess(.terminate, pid: targetPid)
    /// ```
    @inlinable
    public static func toProcess(
        _ signal: Kernel.Signal.Number,
        pid: Kernel.Process.ID
    ) throws(Kernel.Signal.Error) {
        guard kill(pid.rawValue, signal.rawValue) == 0 else {
            throw .send(.captureErrno())
        }
    }

    /// Sends a signal to the calling process.
    ///
    /// - Parameter signal: The signal to send.
    /// - Throws: `Kernel.Signal.Error.send` on failure.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Send SIGUSR1 to self
    /// try Kernel.Signal.Send.toSelf(.user1)
    /// ```
    @inlinable
    public static func toSelf(
        _ signal: Kernel.Signal.Number
    ) throws(Kernel.Signal.Error) {
        guard raise(signal.rawValue) == 0 else {
            throw .send(.captureErrno())
        }
    }

    /// Sends a signal to a process group.
    ///
    /// - Parameters:
    ///   - signal: The signal to send.
    ///   - pgid: The target process group ID.
    /// - Throws: `Kernel.Signal.Error.send` on failure.
    ///
    /// ## Implementation
    ///
    /// Uses `kill(-pgid, sig)` where the negative PID indicates a process group.
    ///
    /// ## Common Errors
    ///
    /// - `.noPermission` (EPERM): Caller lacks permission to send signal.
    /// - `.noSuchProcess` (ESRCH): No process group with the specified ID exists.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Send SIGTERM to current process group
    /// try Kernel.Signal.Send.toGroup(.terminate, pgid: .current)
    /// ```
    @inlinable
    public static func toGroup(
        _ signal: Kernel.Signal.Number,
        pgid: Kernel.Process.Group.ID
    ) throws(Kernel.Signal.Error) {
        // Negative PID means process group
        guard kill(-pgid.rawValue, signal.rawValue) == 0 else {
            throw .send(.captureErrno())
        }
    }
}

#endif

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
        internal import Darwin
        internal import CDarwinShim
    #elseif canImport(Glibc)
        internal import Glibc
    #elseif canImport(Musl)
        internal import Musl
    #endif

    extension Kernel.Process {
        /// Fork operations namespace.
        public enum Fork {}
    }

    // MARK: - Result

    extension Kernel.Process.Fork {
        /// Result of fork() indicating parent or child.
        public enum Result: Sendable, Equatable {
            /// In child process (fork returned 0).
            case child

            /// In parent process with child's PID.
            ///
            /// Label is `child:` not `childPID:` — type already encodes it.
            case parent(child: Kernel.Process.ID)
        }
    }

    // MARK: - Fork Operation

    extension Kernel.Process.Fork {
        /// Creates a new process by duplicating the calling process.
        ///
        /// - Returns: `.child` in the child process, `.parent(child:)` in the parent.
        /// - Throws: `Kernel.Process.Error.fork` on failure.
        ///
        /// ## Common Errors
        ///
        /// - `.resourceLimit` (EAGAIN): System process limit reached, or
        ///   insufficient memory to copy page tables.
        /// - `.resourceLimit` (ENOMEM): Insufficient kernel memory.
        ///
        /// ## Warning
        ///
        /// `fork()` is unsafe in multithreaded programs. Only async-signal-safe
        /// functions may be called between `fork()` and `exec()` in the child.
        /// See `signal-safety(7)` for the list of safe functions.
        ///
        /// ## Usage
        ///
        /// ```swift
        /// switch try Kernel.Process.Fork.fork() {
        /// case .child:
        ///     // In child process
        ///     try Kernel.Process.Execute.execve(...)
        ///     Kernel.Process.Exit.now(127) // execute failed
        /// case .parent(let child):
        ///     // In parent process
        ///     let result = try Kernel.Process.Wait.wait(.process(child))
        /// }
        /// ```
        public static func fork() throws(Kernel.Process.Error) -> Result {
            #if canImport(Darwin)
                let pid = swift_fork()
            #elseif canImport(Glibc)
                let pid = Glibc.fork()
            #elseif canImport(Musl)
                let pid = Musl.fork()
            #endif

            switch pid {
            case -1:
                throw .fork(.captureErrno())
            case 0:
                return .child
            default:
                return .parent(child: Kernel.Process.ID(pid))
            }
        }
    }

#endif

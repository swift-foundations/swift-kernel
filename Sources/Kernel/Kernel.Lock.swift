// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Kernel {
    /// File locking types and options.
    public enum Lock {}
}

// MARK: - Lock Errors

extension Kernel.Lock {
    /// Lock operation errors.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// Lock contention - another process holds a conflicting lock.
        /// - POSIX: `EAGAIN` on `F_SETLK` (non-blocking)
        /// - Windows: `ERROR_LOCK_VIOLATION`
        ///
        /// This is only thrown when `wait: false`. Use `try?` pattern:
        /// ```swift
        /// if (try? Kernel.Lock.lock(fd, range: .file, exclusive: true, wait: false)) != nil {
        ///     // Lock acquired
        /// }
        /// ```
        case contention

        /// Deadlock detected.
        /// - POSIX: `EDEADLK`
        ///
        /// The kernel detected that acquiring this lock would cause
        /// a deadlock with another process.
        case deadlock

        /// No locks available - system lock table exhausted.
        /// - POSIX: `ENOLCK`
        ///
        /// This is resource exhaustion, not contention.
        case unavailable
    }
}

extension Kernel.Lock.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .contention: return "lock contention"
        case .deadlock: return "deadlock detected"
        case .unavailable: return "no locks available"
        }
    }
}

extension Kernel.Lock {
    /// The range of bytes to lock within a file.
    public enum Range: Sendable, Equatable, Hashable {
        /// Lock the entire file.
        case file

        /// Lock a specific byte range.
        ///
        /// - Parameters:
        ///   - start: The starting byte offset (inclusive).
        ///   - end: The ending byte offset (exclusive). Use `UInt64.max` to lock to EOF.
        ///
        /// This matches Swift's `Range<UInt64>` semantics (half-open interval).
        case bytes(start: UInt64, end: UInt64)

        /// Creates a byte range from a Swift Range.
        ///
        /// - Parameter range: The byte range to lock.
        @inlinable
        public init(_ range: Swift.Range<UInt64>) {
            self = .bytes(start: range.lowerBound, end: range.upperBound)
        }
    }

    /// Lock type (shared vs exclusive).
    public enum Kind: Sendable, Equatable, Hashable {
        /// Shared (read) lock. Multiple processes can hold shared locks.
        case shared

        /// Exclusive (write) lock. Only one process can hold an exclusive lock.
        case exclusive
    }
}

// MARK: - Acquisition Strategy

extension Kernel.Lock {
    /// Lock acquisition strategy.
    public enum Acquire: Sendable, Equatable {
        /// Try once without blocking. Returns immediately.
        case `try`

        /// Wait indefinitely until the lock is available.
        case wait

        /// Wait until the deadline, polling with exponential backoff.
        ///
        /// - Parameter deadline: The absolute time by which the lock must be acquired.
        case deadline(ContinuousClock.Instant)

        /// Creates a deadline-based acquisition from a duration.
        ///
        /// - Parameter timeout: The maximum time to wait.
        /// - Returns: An acquisition strategy with a deadline.
        public static func timeout(_ duration: Duration) -> Acquire {
            .deadline(ContinuousClock.now.advanced(by: duration))
        }
    }
}

extension Kernel.Lock.Error {
    /// Lock acquisition timed out.
    ///
    /// Thrown when `.deadline(...)` acquisition cannot acquire the lock
    /// before the deadline expires.
    public static let timedOut = Self.contention  // Reuse contention semantically

    /// Lock would block (for `.try` acquisition).
    public static let wouldBlock = Self.contention
}

// MARK: - Token (RAII Lock Wrapper)

extension Kernel.Lock {
    /// A move-only token representing a held file lock.
    ///
    /// `Token` ensures the lock is released when it goes out of scope.
    /// It is `~Copyable` to prevent accidental duplication of lock ownership.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let token = try Kernel.Lock.Token(
    ///     descriptor: fd,
    ///     range: .file,
    ///     kind: .exclusive
    /// )
    /// defer { token.release() }
    ///
    /// // ... use the locked file ...
    /// ```
    ///
    /// ## Lifetime
    ///
    /// - `release()` is the canonical way to release the lock
    /// - `deinit` releases the lock as a backstop (correctness should not depend on this)
    /// - Once released, the token cannot be used
    ///
    /// ## Thread Safety
    ///
    /// Token stores a `Kernel.Descriptor` which is conditionally `Sendable`.
    /// The mutable `isReleased` state is safe because `~Copyable` ensures
    /// single ownership - only one thread can own the token at a time.
    public struct Token: ~Copyable {
        private let descriptor: Kernel.Descriptor
        private let range: Range
        private var isReleased: Bool

        /// Creates a lock token by acquiring a lock.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor.
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        ///   - acquire: The acquisition strategy (default: `.wait`).
        /// - Throws: `Kernel.Lock.Error` if locking fails.
        public init(
            descriptor: Kernel.Descriptor,
            range: Range = .file,
            kind: Kind,
            acquire: Acquire = .wait
        ) throws(Error) {
            self.descriptor = descriptor
            self.range = range
            self.isReleased = false

            try Self.acquireLock(
                descriptor: descriptor,
                range: range,
                kind: kind,
                acquire: acquire
            )
        }

        /// Releases the lock.
        ///
        /// This is the canonical way to release the lock. After calling,
        /// the token is consumed and cannot be used.
        ///
        /// - Note: This is a best-effort, non-throwing operation.
        public consuming func release() {
            guard !isReleased else { return }
            isReleased = true
            try? Kernel.Lock.unlock(descriptor, range: range)
        }

        deinit {
            // Backstop release - correctness should not depend on this
            guard !isReleased else { return }
            try? Kernel.Lock.unlock(descriptor, range: range)
        }
    }
}

// MARK: - Token Sendable

#if os(Windows)
    // On Windows, Kernel.Descriptor uses @unchecked Sendable.
    // Token's mutable isReleased is safe because ~Copyable ensures single ownership.
    extension Kernel.Lock.Token: @unchecked Sendable {}
#else
    extension Kernel.Lock.Token: Sendable {}
#endif

// MARK: - Token Acquisition Logic

extension Kernel.Lock.Token {
    /// Acquires a lock using the specified strategy.
    private static func acquireLock(
        descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range,
        kind: Kernel.Lock.Kind,
        acquire: Kernel.Lock.Acquire
    ) throws(Kernel.Lock.Error) {
        switch acquire {
        case .try:
            let acquired = try Kernel.Lock.tryLock(descriptor, range: range, kind: kind)
            if !acquired {
                throw .contention
            }

        case .wait:
            try Kernel.Lock.lock(descriptor, range: range, kind: kind)

        case .deadline(let deadline):
            try acquireWithDeadline(
                descriptor: descriptor,
                range: range,
                kind: kind,
                deadline: deadline
            )
        }
    }

    /// Polls for a lock until the deadline expires.
    ///
    /// Uses exponential backoff starting at 1ms, capped at 100ms.
    private static func acquireWithDeadline(
        descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range,
        kind: Kernel.Lock.Kind,
        deadline: ContinuousClock.Instant
    ) throws(Kernel.Lock.Error) {
        var backoff: Duration = .milliseconds(1)
        let maxBackoff: Duration = .milliseconds(100)

        while true {
            // Check deadline first
            let now = ContinuousClock.now
            if now >= deadline {
                throw .contention
            }

            // Try to acquire
            let acquired = try Kernel.Lock.tryLock(descriptor, range: range, kind: kind)

            if acquired {
                // Critical: re-check deadline after acquisition
                // If deadline passed, unlock and throw to maintain invariant:
                // "success means lock was acquired before deadline"
                if ContinuousClock.now >= deadline {
                    try? Kernel.Lock.unlock(descriptor, range: range)
                    throw .contention
                }
                return
            }

            // Calculate sleep time (don't overshoot deadline)
            let remaining = deadline - ContinuousClock.now
            if remaining <= .zero {
                throw .contention
            }

            let sleepDuration = min(backoff, remaining)
            sleep(sleepDuration)

            // Exponential backoff with cap
            backoff = min(backoff * 2, maxBackoff)
        }
    }

    /// Platform-specific sleep without Foundation dependency.
    private static func sleep(_ duration: Duration) {
        let (seconds, attoseconds) = duration.components
        let nanoseconds = UInt64(seconds) * 1_000_000_000 + UInt64(attoseconds) / 1_000_000_000

        #if os(Windows)
            let milliseconds = nanoseconds / 1_000_000
            Sleep(DWORD(min(milliseconds, UInt64(DWORD.max))))
        #else
            var ts = timespec()
            ts.tv_sec = Int(nanoseconds / 1_000_000_000)
            ts.tv_nsec = Int(nanoseconds % 1_000_000_000)
            nanosleep(&ts, nil)
        #endif
    }
}

// MARK: - Scoped Locking Helpers

extension Kernel.Lock {
    /// Executes a closure while holding an exclusive lock.
    ///
    /// The lock is automatically released when the closure completes.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor.
    ///   - range: The byte range to lock (default: whole file).
    ///   - acquire: The acquisition strategy (default: `.wait`).
    ///   - body: The closure to execute while holding the lock.
    /// - Returns: The result of the closure.
    /// - Throws: `Kernel.Lock.Error` if locking fails, or rethrows from the closure.
    public static func withExclusive<T>(
        _ descriptor: Kernel.Descriptor,
        range: Range = .file,
        acquire: Acquire = .wait,
        _ body: () throws -> T
    ) throws -> T {
        let token = try Token(descriptor: descriptor, range: range, kind: .exclusive, acquire: acquire)
        let result = try body()
        _ = consume token
        return result
    }

    /// Executes a closure while holding a shared lock.
    ///
    /// The lock is automatically released when the closure completes.
    ///
    /// - Parameters:
    ///   - descriptor: The file descriptor.
    ///   - range: The byte range to lock (default: whole file).
    ///   - acquire: The acquisition strategy (default: `.wait`).
    ///   - body: The closure to execute while holding the lock.
    /// - Returns: The result of the closure.
    /// - Throws: `Kernel.Lock.Error` if locking fails, or rethrows from the closure.
    public static func withShared<T>(
        _ descriptor: Kernel.Descriptor,
        range: Range = .file,
        acquire: Acquire = .wait,
        _ body: () throws -> T
    ) throws -> T {
        let token = try Token(descriptor: descriptor, range: range, kind: .shared, acquire: acquire)
        let result = try body()
        _ = consume token
        return result
    }
}

// MARK: - POSIX Implementation

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
        public import CLinuxShim
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Lock {
        /// Acquires a lock on a byte range (blocking).
        ///
        /// This call blocks until the lock can be acquired.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor.
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Throws: `Error.deadlock` if a deadlock is detected,
        ///           `Error.unavailable` if the system lock table is exhausted.
        @inlinable
        public static func lock(
            _ descriptor: Kernel.Descriptor,
            range: Range,
            kind: Kind
        ) throws(Error) {
            var fl = makeFlock(range: range, kind: kind)

            let result = fcntl(descriptor.rawValue, F_SETLKW, &fl)
            guard result != -1 else {
                throw Error.fromErrno(errno)
            }
        }

        /// Attempts to acquire a lock without blocking.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor.
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Returns: `true` if the lock was acquired, `false` if it would block.
        /// - Throws: `Error.deadlock` if a deadlock is detected,
        ///           `Error.unavailable` if the system lock table is exhausted.
        @inlinable
        public static func tryLock(
            _ descriptor: Kernel.Descriptor,
            range: Range,
            kind: Kind
        ) throws(Error) -> Bool {
            var fl = makeFlock(range: range, kind: kind)

            let result = fcntl(descriptor.rawValue, F_SETLK, &fl)
            if result == -1 {
                // EAGAIN or EACCES means the lock is held by another process
                if errno == EAGAIN || errno == EACCES {
                    return false
                }
                throw Error.fromErrno(errno)
            }
            return true
        }

        /// Releases a lock on a byte range.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor.
        ///   - range: The byte range to unlock.
        /// - Throws: `Error` if unlocking fails.
        @inlinable
        public static func unlock(
            _ descriptor: Kernel.Descriptor,
            range: Range
        ) throws(Error) {
            var fl = flock()
            fl.l_type = Int16(F_UNLCK)
            fl.l_whence = Int16(SEEK_SET)

            switch range {
            case .file:
                fl.l_start = 0
                fl.l_len = 0  // 0 means lock to EOF
            case .bytes(let start, let end):
                fl.l_start = off_t(start)
                fl.l_len = off_t(end - start)
            }

            let result = fcntl(descriptor.rawValue, F_SETLK, &fl)
            guard result != -1 else {
                throw Error.fromErrno(errno)
            }
        }

        /// Creates a flock structure for fcntl.
        @inlinable
        static func makeFlock(range: Range, kind: Kind) -> flock {
            var fl = flock()

            fl.l_type = kind == .shared ? Int16(F_RDLCK) : Int16(F_WRLCK)
            fl.l_whence = Int16(SEEK_SET)

            switch range {
            case .file:
                // l_start = 0, l_len = 0 means "lock entire file to EOF"
                fl.l_start = 0
                fl.l_len = 0
            case .bytes(let start, let end):
                fl.l_start = off_t(start)
                fl.l_len = off_t(end - start)
            }

            return fl
        }
    }

    extension Kernel.Lock.Error {
        /// Maps errno to lock error.
        @inlinable
        static func fromErrno(_ errno: Int32) -> Self {
            switch errno {
            case EDEADLK:
                return .deadlock
            case ENOLCK:
                return .unavailable
            default:
                // EAGAIN/EACCES are handled in tryLock, shouldn't reach here
                return .contention
            }
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)
    public import WinSDK

    extension Kernel.Lock {
        /// Acquires a lock on a byte range (blocking).
        ///
        /// This call blocks until the lock can be acquired.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor (Windows HANDLE).
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Throws: `Error.unavailable` on failure.
        @inlinable
        public static func lock(
            _ descriptor: Kernel.Descriptor,
            range: Range,
            kind: Kind
        ) throws(Error) {
            var overlapped = makeOverlapped(range: range)
            let (lengthLow, lengthHigh) = lockLength(range: range)

            // For blocking, don't use LOCKFILE_FAIL_IMMEDIATELY
            let flags: DWORD = kind == .exclusive ? DWORD(LOCKFILE_EXCLUSIVE_LOCK) : 0

            let result = LockFileEx(
                descriptor.rawValue,
                flags,
                0,
                lengthLow,
                lengthHigh,
                &overlapped
            )

            guard result else {
                throw Error.fromWindowsError(GetLastError())
            }
        }

        /// Attempts to acquire a lock without blocking.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor (Windows HANDLE).
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Returns: `true` if the lock was acquired, `false` if it would block.
        /// - Throws: `Error` on failure other than contention.
        @inlinable
        public static func tryLock(
            _ descriptor: Kernel.Descriptor,
            range: Range,
            kind: Kind
        ) throws(Error) -> Bool {
            var overlapped = makeOverlapped(range: range)
            let (lengthLow, lengthHigh) = lockLength(range: range)

            var flags: DWORD = DWORD(LOCKFILE_FAIL_IMMEDIATELY)
            if kind == .exclusive {
                flags |= DWORD(LOCKFILE_EXCLUSIVE_LOCK)
            }

            let result = LockFileEx(
                descriptor.rawValue,
                flags,
                0,
                lengthLow,
                lengthHigh,
                &overlapped
            )

            if !result {
                let error = GetLastError()
                if error == DWORD(ERROR_LOCK_VIOLATION) || error == DWORD(ERROR_LOCK_FAILED) {
                    return false
                }
                throw Error.fromWindowsError(error)
            }
            return true
        }

        /// Releases a lock on a byte range.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor (Windows HANDLE).
        ///   - range: The byte range to unlock.
        /// - Throws: `Error` if unlocking fails.
        @inlinable
        public static func unlock(
            _ descriptor: Kernel.Descriptor,
            range: Range
        ) throws(Error) {
            var overlapped = makeOverlapped(range: range)
            let (lengthLow, lengthHigh) = lockLength(range: range)

            let result = UnlockFileEx(
                descriptor.rawValue,
                0,
                lengthLow,
                lengthHigh,
                &overlapped
            )

            guard result else {
                throw Error.fromWindowsError(GetLastError())
            }
        }

        /// Creates an OVERLAPPED structure for the given range.
        @inlinable
        static func makeOverlapped(range: Range) -> OVERLAPPED {
            var overlapped = OVERLAPPED()
            let start: UInt64
            switch range {
            case .file:
                start = 0
            case .bytes(let s, _):
                start = s
            }
            overlapped.Offset = DWORD(start & 0xFFFF_FFFF)
            overlapped.OffsetHigh = DWORD(start >> 32)
            return overlapped
        }

        /// Computes the DWORD pair for the lock length.
        ///
        /// Windows LockFileEx locks exact byte counts (unlike POSIX's "to EOF" with l_len=0).
        @inlinable
        static func lockLength(range: Range) -> (low: DWORD, high: DWORD) {
            switch range {
            case .file:
                // Use max DWORD values to lock the largest possible range from offset 0.
                // This is the Windows equivalent of "lock entire file".
                return (DWORD.max, DWORD.max)
            case .bytes(let start, let end):
                let length = end - start
                return (DWORD(length & 0xFFFF_FFFF), DWORD(length >> 32))
            }
        }
    }

    extension Kernel.Lock.Error {
        /// Maps Windows error code to lock error.
        @inlinable
        static func fromWindowsError(_ error: DWORD) -> Self {
            switch error {
            case DWORD(ERROR_LOCK_VIOLATION), DWORD(ERROR_SHARING_VIOLATION), DWORD(ERROR_LOCK_FAILED):
                return .contention
            default:
                return .unavailable
            }
        }
    }

#endif

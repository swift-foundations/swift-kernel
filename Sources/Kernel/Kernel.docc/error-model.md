# Error Model and Platform Codes

Understanding swift-kernel's typed error system and cross-platform error handling.

## Overview

swift-kernel uses Swift's typed throws to provide precise, actionable error information. Unlike many libraries that erase error types or use generic `Error`, every function declares exactly which errors it can throw.

## Typed Throws Philosophy

Every syscall wrapper declares its specific error type:

```swift
// The error type is part of the function signature
public static func open(
    path: String,
    mode: Mode,
    options: Options
) throws(Kernel.File.Open.Error) -> Kernel.Descriptor

public static func read(
    _ descriptor: Kernel.Descriptor,
    into buffer: UnsafeMutableRawBufferPointer
) throws(Kernel.IO.Read.Error) -> Int
```

This enables:
- **Exhaustive switch** over error cases without a `default`
- **Compile-time checking** that you handle all possible errors
- **No type erasure** - errors carry their full context

## Error Code Abstraction

Platform error codes (POSIX `errno`, Windows `GetLastError()`) are abstracted through ``Kernel/Error/Code``:

```swift
public enum Code: Sendable, Equatable, Hashable {
    /// POSIX errno value (Darwin, Linux)
    case posix(Int32)

    /// Windows error code (GetLastError)
    case win32(UInt32)
}
```

This code is captured at the syscall boundary and never leaks raw platform values:

```swift
// Internal: capture immediately after syscall
let code = Kernel.Error.Code.captureErrno()  // POSIX
let code = Kernel.Error.Code.captureLastError()  // Windows
```

## Domain-Specific Errors

Errors are organized by domain, each with semantic cases that map to platform codes:

### Path Resolution Errors

```swift
public enum Kernel.Path.Resolution.Error {
    /// Path component does not exist
    /// - POSIX: ENOENT
    /// - Windows: ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND
    case notFound(Kernel.Error.Code)

    /// Path component is not a directory
    /// - POSIX: ENOTDIR
    case notDirectory(Kernel.Error.Code)

    /// Path has too many symbolic link levels
    /// - POSIX: ELOOP
    case loop(Kernel.Error.Code)
}
```

### I/O Errors

```swift
public enum Kernel.IO.Error {
    /// Broken pipe - peer closed the connection
    /// - POSIX: EPIPE
    /// - Windows: ERROR_BROKEN_PIPE
    case broken

    /// Connection reset by peer
    /// - POSIX: ECONNRESET
    case reset

    /// Physical I/O error
    /// - POSIX: EIO
    /// - Windows: ERROR_IO_DEVICE
    case hardware
}
```

### Permission Errors

```swift
public enum Kernel.Permission.Error {
    /// Operation not permitted for this user
    /// - POSIX: EACCES, EPERM
    /// - Windows: ERROR_ACCESS_DENIED
    case denied(Kernel.Error.Code)
}
```

## Error Recovery Patterns

### Pattern 1: Exhaustive Matching

```swift
do {
    let fd = try Kernel.File.Open.open(path: path, mode: [.read], options: [])
    defer { try? Kernel.Close.close(fd) }
    // Use fd...
} catch {
    switch error {
    case .notFound(let code):
        print("File not found: \(Kernel.Error.message(for: code) ?? "unknown")")
    case .permission(let permError):
        print("Permission denied")
    case .exists:
        print("File already exists (exclusive create failed)")
    // ... handle all cases
    }
}
```

### Pattern 2: Specific Error Handling

```swift
do {
    try Kernel.Lock.lock(fd, range: .file, kind: .exclusive)
} catch .contention {
    // Another process holds a conflicting lock
    // Try again later or use a different strategy
} catch .deadlock {
    // Deadlock detected - release other locks first
} catch {
    // Handle other lock errors
}
```

### Pattern 3: Optional Conversion

```swift
// Non-blocking lock attempt
if (try? Kernel.Lock.tryLock(fd, range: .file, kind: .exclusive)) != nil {
    defer { try? Kernel.Lock.unlock(fd, range: .file) }
    // Lock acquired, do exclusive work
} else {
    // Lock not available, handle gracefully
}
```

## Platform Error Messages

Get human-readable error messages for any error code:

```swift
if let message = Kernel.Error.message(for: code) {
    print("Error: \(message)")
}
// POSIX: calls strerror()
// Windows: calls FormatMessageW()
```

## The Unified Error Type

For generic syscall contexts, ``Kernel/Error`` aggregates all domain errors:

```swift
public enum Kernel.Error {
    case path(Kernel.Path.Resolution.Error)
    case handle(Kernel.Descriptor.Validity.Error)
    case io(Kernel.IO.Error)
    case lock(Kernel.Lock.Error)
    case memory(Kernel.Memory.Error)
    case permission(Kernel.Permission.Error)
    case space(Kernel.Storage.Error)
    case signal(Kernel.Signal.Error)
    case blocking(Kernel.IO.Blocking.Error)
    case platform(Kernel.Error.Unmapped.Error)
}
```

This is used sparingly - prefer domain-specific errors when possible.

## Topics

### Error Types

- ``Kernel/Error``
- ``Kernel/Error/Code``
- ``Kernel/Path/Resolution/Error``
- ``Kernel/IO/Error``
- ``Kernel/Permission/Error``
- ``Kernel/Lock/Error``
- ``Kernel/Memory/Error``

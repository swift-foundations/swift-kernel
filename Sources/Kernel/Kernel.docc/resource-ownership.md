# Resource Ownership and ~Copyable Handles

Understanding move-only types and safe resource management in swift-kernel.

## Overview

swift-kernel uses Swift's `~Copyable` (noncopyable) types for resources that represent unique kernel handles. This prevents accidental resource leaks and use-after-close bugs at compile time.

## Why Move-Only?

Kernel resources like file descriptors, locks, and threads have identity - they cannot be meaningfully copied. Closing a "copy" would close the original, leading to subtle bugs:

```swift
// DANGEROUS with copyable types:
let fd = open(...)
let copy = fd  // If this were allowed...
close(copy)    // ...this would close the REAL resource
read(fd, ...)  // ...and this would fail or read from wrong file!
```

By making handles `~Copyable`, the compiler prevents this:

```swift
// SAFE with noncopyable types:
let handle = Kernel.File.Handle(...)
let copy = handle  // Compile error: cannot copy noncopyable type
// Only explicit move is allowed:
let moved = consume handle  // handle is now invalid
```

## Noncopyable Types in swift-kernel

### File Handles

``Kernel/File/Handle`` owns a file descriptor and closes it on deinit:

```swift
public struct Handle: ~Copyable, Sendable {
    public let descriptor: Kernel.Descriptor

    /// Takes ownership of a raw descriptor.
    /// The descriptor will be closed when this handle is consumed.
    public init(takingOwnership descriptor: Kernel.Descriptor)

    deinit {
        try? Kernel.Close.close(descriptor)
    }
}
```

Usage:

```swift
func processFile(at path: String) throws {
    let fd = try Kernel.File.Open.open(path: path, mode: [.read], options: [])
    let handle = Kernel.File.Handle(takingOwnership: fd)
    // handle owns fd now

    // Use the descriptor through the handle
    var buffer = [UInt8](repeating: 0, count: 4096)
    try buffer.withUnsafeMutableBytes { buf in
        _ = try Kernel.IO.Read.read(handle.descriptor, into: buf)
    }

    // handle.deinit automatically closes fd when function returns
}
```

### Lock Tokens

``Kernel/Lock/Token`` represents an acquired lock that must be released:

```swift
public struct Token: ~Copyable, Sendable {
    public let descriptor: Kernel.Descriptor
    public let range: Kernel.Lock.Range

    deinit {
        try? Kernel.Lock.unlock(descriptor, range: range)
    }
}
```

Usage:

```swift
func withExclusiveAccess<T>(
    to fd: Kernel.Descriptor,
    body: () throws -> T
) throws -> T {
    let token = try Kernel.Lock.lock(fd, range: .file, kind: .exclusive)
    defer { _ = consume token }  // Explicit release at scope exit
    return try body()
}
```

### Thread Handles

``Kernel/Thread/Handle`` represents a thread that must be joined or detached:

```swift
public struct Handle: ~Copyable, Sendable {
    // Thread must be joined or detached before handle is dropped
    deinit {
        // Warning: dropping without join/detach is a programmer error
    }
}
```

## The defer Pattern

Even with automatic cleanup in `deinit`, prefer explicit `defer` for clarity:

```swift
func readFile(path: String) throws -> Data {
    let fd = try Kernel.File.Open.open(path: path, mode: [.read], options: [])
    defer { try? Kernel.Close.close(fd) }  // Clear intent, predictable timing

    // ... read operations ...
}
```

Benefits of explicit `defer`:
- **Visible intent** - readers see the cleanup strategy immediately
- **Predictable timing** - cleanup happens at scope exit, not "sometime later"
- **Works with raw descriptors** - when you can't use a Handle wrapper

## Common Patterns

### Pattern 1: Scoped Resource

```swift
func withOpenFile<T>(
    path: String,
    mode: Kernel.File.Open.Mode,
    body: (Kernel.Descriptor) throws -> T
) throws -> T {
    let fd = try Kernel.File.Open.open(path: path, mode: mode, options: [])
    defer { try? Kernel.Close.close(fd) }
    return try body(fd)
}

// Usage:
try withOpenFile(path: "/tmp/data.txt", mode: [.read]) { fd in
    // fd is valid here, automatically closed after
}
```

### Pattern 2: Transfer Ownership

```swift
/// Opens a file and transfers ownership to the caller.
/// Caller is responsible for closing the returned descriptor.
func openForTransfer(path: String) throws -> Kernel.File.Handle {
    let fd = try Kernel.File.Open.open(path: path, mode: [.read], options: [])
    return Kernel.File.Handle(takingOwnership: fd)
    // Caller now owns the handle
}
```

### Pattern 3: Borrow Without Ownership

```swift
/// Reads from a descriptor without taking ownership.
/// Caller remains responsible for the descriptor's lifetime.
func readAll(from descriptor: Kernel.Descriptor) throws -> [UInt8] {
    var result = [UInt8]()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while true {
        let bytesRead = try buffer.withUnsafeMutableBytes { buf in
            try Kernel.IO.Read.read(descriptor, into: buf)
        }
        if bytesRead == 0 { break }  // EOF
        result.append(contentsOf: buffer.prefix(bytesRead))
    }

    return result
    // descriptor is NOT closed - caller still owns it
}
```

## Misuse Prevention

The `~Copyable` design prevents these common bugs:

| Bug | Prevention |
|-----|------------|
| Double close | Can't copy handle, so can't close twice |
| Use after close | Original handle invalid after `consume` |
| Leaked descriptor | `deinit` ensures cleanup |
| Accidental aliasing | No hidden copies of the resource |

## Topics

### Noncopyable Types

- ``Kernel/File/Handle``
- ``Kernel/Lock/Token``
- ``Kernel/Thread/Handle``

### Related

- ``Kernel/Close``
- ``Kernel/Lock``

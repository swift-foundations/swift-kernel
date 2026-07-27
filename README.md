# swift-kernel

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-foundations/swift-kernel/workflows/CI/badge.svg)](https://github.com/swift-foundations/swift-kernel/actions/workflows/ci.yml)

Policy-free syscall wrappers for Swift. Provides raw descriptors, typed throws, and unified error types across macOS, Linux, and Windows. Swift 6 strict concurrency with Foundation-free design.

---

## Key Features

- **Raw syscall wrappers** – No policy, no retry logic, no derived semantics
- **Typed throws** – No `any Error` at the API surface, with `Kernel.Failure` for abstraction boundaries
- **Platform-native surfaces** – `Kernel.Kqueue` (Darwin), `Kernel.IOUring` (Linux), `Kernel.IOCP` (Windows)
- **Foundation-free** – No Foundation module dependencies; no URL, Data, or Foundation string types
- **Swift 6 strict concurrency** – Full `Sendable` compliance

---

## Installation

### Package.swift dependency

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-kernel.git", branch: "main")
]
```

> Pre-1.0: no version tags yet. APIs may change; pin a commit for reproducible builds.

### Target dependency

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Kernel", package: "swift-kernel")
    ]
)
```

### Requirements

- Swift 6.2+
- macOS 26.0+ / iOS 26.0+ / tvOS 26.0+ / watchOS 26.0+
- Linux (Ubuntu 22.04+)
- Windows (Swift 6.2+)

---

## Quick Start

### File Operations

```swift
import Kernel
import SystemPackage

// Open a file (FilePath convenience overload)
let fd = try Kernel.File.Open.open(
    path: FilePath("/tmp/test.txt"),
    mode: .readWrite,
    options: [.create, .truncate],
    permissions: 0o644
)

// Read bytes
var buffer = [UInt8](repeating: 0, count: 1024)
let bytesRead = try buffer.withUnsafeMutableBytes { ptr in
    try Kernel.IO.Read.read(fd, into: ptr)
}

// Write bytes
let data = Array("Hello".utf8)
let bytesWritten = try data.withUnsafeBytes { ptr in
    try Kernel.IO.Write.write(fd, from: ptr)
}

// Close
try Kernel.Close.close(fd)
```

### Thread Spawning with Ownership Transfer

```swift
import Kernel

// Spawn a thread with value transfer (for ~Copyable types)
let handle = try Kernel.Thread.spawn(myResource) { resource in
    // Ownership of resource transferred to this thread
    process(resource)
}
handle.join()
```

---

## Error Handling

Kernel uses typed throws throughout. Each operation throws its own domain-specific error type:

```swift
// Kernel.File.Open.open throws(Kernel.File.Open.Error)
do {
    let fd = try Kernel.File.Open.open(
        path: FilePath("/tmp/x"),
        mode: .read,
        options: [],
        permissions: 0
    )
} catch {
    switch error {
    case .notFound:
        print("File doesn't exist")
    case .permission:
        print("Permission denied")
    case .isDirectory:
        print("Path is a directory")
    }
}
```

`Kernel.Failure` aggregates all domain errors for abstraction boundaries:

```swift
public enum Failure: Swift.Error, Sendable, Equatable {
    case path(Kernel.Path.Resolution.Error)
    case handle(Kernel.Descriptor.Validity.Error)
    case io(Kernel.IO.Error)
    case lock(Kernel.Lock.Error)
    case memory(Kernel.Memory.Error)
    case permission(Kernel.Permission.Error)
    case space(Kernel.Storage.Error)
    case signal(Kernel.Signal.Error)      // non-Windows
    case blocking(Kernel.IO.Blocking.Error)
    case platform(Kernel.Error)
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│               swift-file-system                  │  ← File, File.Directory API
├─────────────────────────────────────────────────┤
│   swift-io   swift-threads   swift-executors    │  ← I/O, thread-layer compositions, executor conformances
├─────────────────────────────────────────────────┤
│                 swift-kernel                     │  ← Syscall wrappers (this package)
├─────────────────────────────────────────────────┤
│          POSIX / Darwin / Windows                │  ← System calls
└─────────────────────────────────────────────────┘
```

### Key Types

| Type                             | Purpose                                              |
|----------------------------------|------------------------------------------------------|
| `Kernel.Descriptor`              | File descriptor (POSIX) or HANDLE (Windows)          |
| `Kernel.Failure`                 | Unified error aggregation for abstraction boundaries |
| `Kernel.Path`                    | Validated path wrapper (platform strings)            |
| `Kernel.File.Open`               | File open operations with mode, options, permissions |
| `Kernel.File.Handle`             | RAII file handle (~Copyable) with Direct I/O support |
| `Kernel.File.Clone`              | File cloning with reflink/copy fallback              |
| `Kernel.IO.Read/Write`           | Positional and sequential I/O operations             |
| `Kernel.Memory.Map`              | Memory mapping operations                            |
| `Kernel.Lock`                    | File locking (fcntl/LockFileEx)                      |
| `Kernel.Kqueue`                  | Darwin event notification                            |
| `Kernel.IOUring`                 | Linux io_uring interface                             |
| `Kernel.IOCP`                    | Windows I/O completion ports                         |
| `Kernel.Thread.Handle`           | pthread_t / HANDLE wrapper (join, detach)            |
| `Kernel.Thread.spawn`            | Thread creation with ownership transfer              |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS            | ✅  | Full support |
| Linux            | ✅  | Full support |
| Windows          | ✅  | Full support |
| iOS/tvOS/watchOS | —   | Supported    |

### io_uring Support

io_uring is available on Linux kernel 5.1+. Runtime detection:

```swift
if Kernel.IOUring.isSupported {
    // Use io_uring backend
} else {
    // Fall back to epoll
}
```

Can be disabled via environment: `IO_URING_DISABLED=1`

---

## Design Philosophy

swift-kernel is the lowest layer in the Systems stack. It provides syscall-shaped APIs that higher layers build upon.

### Paths and Strings

Kernel exposes two path representations:

- `SystemPackage.FilePath` is supported by convenience overloads for ergonomics and portability.
- `Kernel.Path` represents validated, null-terminated platform strings intended for direct syscall use.

Higher layers are expected to prefer `FilePath`. `Kernel.Path` exists for:
- Zero-allocation syscall paths
- Embedding Kernel in lower-level runtimes
- Avoiding `SystemPackage` entirely in constrained environments

### Invariants

Kernel guarantees:
- **Typed throws** – All public APIs use typed throws, no `any Error`
- **No policy** – Raw syscall semantics, no retry logic or best-effort modes
- **No Foundation** – No URL, Data, or Foundation string types
- **No hidden allocation** – Any allocation performed by Kernel APIs is explicit
- **Raw descriptor model** – `Kernel.Descriptor` wraps `Int32` (POSIX) or `HANDLE` (Windows)
- **Explicit platform gating** – `#if canImport(Darwin)`, `#if os(Windows)`, etc.

---

## Related Packages

### Dependencies

- [swift-kernel-primitives](https://github.com/coenttb/swift-kernel-primitives): Low-level syscall bindings
- [swift-posix](https://github.com/swift-foundations/swift-posix): POSIX syscall wrappers
- [swift-darwin](https://github.com/swift-foundations/swift-darwin): Darwin-specific syscalls
- [swift-linux](https://github.com/swift-foundations/swift-linux): Linux-specific syscalls (epoll, io_uring)
- [swift-windows](https://github.com/swift-foundations/swift-windows): Windows-specific syscalls (IOCP)
- [apple/swift-system](https://github.com/apple/swift-system): `FilePath` for path-accepting APIs

### Used By

- [swift-executors](https://github.com/swift-foundations/swift-executors): Swift Executor protocol conformances backed by dedicated OS threads
- [swift-threads](https://github.com/coenttb/swift-threads): Thread-layer compositions (Synchronization, Barrier, Gate, Semaphore, Worker, Pool)
- [swift-io](https://github.com/swift-foundations/swift-io): Async I/O witness with typed throws
- [swift-file-system](https://github.com/swift-foundations/swift-file-system): High-level file operations

---

## License

Apache 2.0 – See [LICENSE](LICENSE.md) for details.

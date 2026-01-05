# swift-kernel

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Policy-free syscall wrappers for Swift. Provides raw descriptors, typed throws, and unified error types across macOS, Linux, and Windows. Swift 6 strict concurrency with Foundation-free design.

## Key Features

- **Raw syscall wrappers** - No policy, no retry logic, no derived semantics
- **Typed throws** - No `any Error` at the API surface, with a provided `Kernel.Error` for abstraction boundaries
- **Platform-native surfaces** - `Kernel.Kqueue` (Darwin), `Kernel.IOUring` (Linux), `Kernel.IOCP` (Windows)
- **Foundation-free** - No Foundation module dependencies; no URL, Data, or Foundation string types
- **Swift 6 strict concurrency** - Full `Sendable` compliance

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

### Exports

**Kernel exports:**
- Raw descriptors (`Kernel.Descriptor`)
- Raw buffers (`UnsafeRawBufferPointer`, `UnsafeMutableRawBufferPointer`)
- Primitive enums/option sets (`Kernel.File.Open.Mode`, `Kernel.File.Open.Options`)
- Unified error type (`Kernel.Error`)
- Path wrappers (`Kernel.Path` for validated platform strings)
- `SystemPackage.FilePath`-accepting convenience overloads for ergonomics
- System queries (`Kernel.System.pageSize`)

**Kernel does NOT export:**
- Foundation types (URL, Data, Foundation strings)
- Policy (atomic writes, best-effort modes, retry logic)
- Discovery (capability probing, alignment requirements interpretation)
- Derived semantics (Direct I/O requirements, file type inference beyond stat)

Higher layers ([swift-io](https://github.com/coenttb/swift-io), [swift-file-system](https://github.com/coenttb/swift-file-system)) build semantics on top of Kernel.

## Installation

Add swift-kernel to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-kernel.git", from: "0.1.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Kernel", package: "swift-kernel"),
    ]
)
```

**Requirements:**
- Swift 6.2+
- macOS 26.0+ / iOS 26.0+ / tvOS 26.0+ / watchOS 26.0+
- Linux (Ubuntu 22.04+)
- Windows (Swift 6.2+)

## Quick Start

### File Descriptors

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

// Positional I/O (no shared file offset)
let bytesAtOffset = try buffer.withUnsafeMutableBytes { ptr in
    try Kernel.IO.Read.pread(fd, into: ptr, at: 100)
}

// Close
try Kernel.Close.close(fd)
```

### Memory Mapping

```swift
// Map a file into memory
let region = try Kernel.Memory.Map.map(
    length: 4096,
    protection: [.read, .write],
    flags: [.shared],
    fd: fd,
    offset: 0
)

// Sync to disk
try Kernel.Memory.Map.sync(addr: region, length: 4096)

// Unmap
try Kernel.Memory.Map.unmap(addr: region, length: 4096)
```

### File Locking

```swift
// Exclusive lock (blocking)
try Kernel.Lock.lock(fd, range: .file, kind: .exclusive)

// Try lock (non-blocking)
if try Kernel.Lock.tryLock(fd, range: .bytes(0, 1024), kind: .shared) {
    // Lock acquired
}

// Unlock
try Kernel.Lock.unlock(fd, range: .file)
```

### Event Notification

```swift
#if canImport(Darwin)
// kqueue (macOS/BSD)
let kq = try Kernel.Kqueue.create()
try Kernel.Kqueue.register(kq, events: [.init(fd: fd, filter: .read)])
let count = try Kernel.Kqueue.poll(kq, into: &events, timeout: .seconds(1))
#endif

#if canImport(Glibc)
// io_uring (Linux 5.1+)
if Kernel.IOUring.isSupported {
    var params = Kernel.IOUring.Params()
    let ring = try Kernel.IOUring.setup(entries: 32, params: &params)
    // Submit and wait for completions
    let submitted = try Kernel.IOUring.enter(ring, toSubmit: 1, minComplete: 1, flags: [])
}
#endif

#if os(Windows)
// IOCP (Windows)
let port = try Kernel.IOCP.create()
try Kernel.IOCP.associate(port, fileHandle: handle, completionKey: .init(rawValue: 1))
#endif
```

### Threading

```swift
// Create OS thread
let handle = try Kernel.Thread.create {
    // Work runs on dedicated OS thread
    print("Running on thread")
}

// Join thread
try Kernel.Thread.join(handle)
```

## Error Model

Kernel uses typed throws throughout. Each operation throws its own domain-specific error type. `Kernel.Error` exists only as an aggregation boundary when composing multiple Kernel subsystems or crossing abstraction layers:

```swift
public enum Error: Swift.Error, Sendable, Equatable {
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

Operations use typed throws for precise error handling:

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
    // error is Kernel.File.Open.Error (typed)
    switch error {
    case .notFound:
        // File doesn't exist
    case .permission:
        // Permission denied
    case .isDirectory:
        // Path is a directory
    // ...
    }
}
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│               swift-file-system                  │  ← File, File.Directory API
├─────────────────────────────────────────────────┤
│                   swift-io                       │  ← Executors, async I/O, completion backends
├─────────────────────────────────────────────────┤
│                 swift-kernel                     │  ← Syscall wrappers (this package)
├─────────────────────────────────────────────────┤
│          POSIX / Darwin / Windows                │  ← System calls
└─────────────────────────────────────────────────┘
```

### Modules

| Module | Contents |
|--------|----------|
| `Kernel` | Core types, descriptors, errors, syscall wrappers |
| `CLinuxShim` | Linux-specific C shims (io_uring) |

### Key Types

| Type | Purpose |
|------|---------|
| `Kernel.Descriptor` | File descriptor (POSIX) or HANDLE (Windows) |
| `Kernel.Error` | Unified syscall error type |
| `Kernel.Path` | Validated path wrapper (platform strings) |
| `Kernel.File.Open` | File open options and modes |
| `Kernel.IO.Read/Write` | Read/write operations |
| `Kernel.Memory.Map` | Memory mapping operations |
| `Kernel.Lock` | File locking (fcntl/LockFileEx) |
| `Kernel.Kqueue` | Darwin event notification |
| `Kernel.IOUring` | Linux io_uring interface |
| `Kernel.IOCP` | Windows I/O completion ports |
| `Kernel.Thread` | OS thread creation |

## Platform Support

Core syscalls are implemented for macOS, Linux, and Windows. Platform-specific event facilities are available where supported.

| Platform | Core Syscalls | Event System |
|----------|---------------|--------------|
| macOS | Implemented | kqueue |
| iOS/tvOS/watchOS | Implemented | kqueue |
| Linux | Implemented | io_uring (5.1+), epoll |
| Windows | Implemented | IOCP |

Kernel exposes platform-native event facilities. Selection, fallback, and policy decisions are the responsibility of higher layers.

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

## Invariants

Kernel guarantees:
- **Typed throws** - All public APIs use typed throws, no `any Error`
- **No policy** - Raw syscall semantics, no retry logic or best-effort modes
- **No Foundation** - No URL, Data, or Foundation string types
- **No hidden allocation** - Any allocation performed by Kernel APIs is explicit and visible at the call site
- **Raw descriptor model** - `Kernel.Descriptor` wraps `Int32` (POSIX) or `HANDLE` (Windows)
- **Explicit platform gating** - `#if canImport(Darwin)`, `#if os(Windows)`, etc.

## Related Packages

### Built on swift-kernel

- [swift-io](https://github.com/coenttb/swift-io) - Async I/O executor with typed throws
- [swift-file-system](https://github.com/coenttb/swift-file-system) - High-level file operations

### Dependencies

- [apple/swift-system](https://github.com/apple/swift-system) - `FilePath` for path-accepting APIs
- [swift-standards](https://github.com/swift-standards/swift-standards) - Test support

## License

Apache 2.0 - See [LICENSE](LICENSE.md) for details.

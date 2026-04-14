# swift-kernel Overview

Policy-free syscall wrappers for Darwin, Linux, and Windows.

## Overview

swift-kernel provides type-safe, Foundation-free syscall wrappers that expose raw kernel semantics without imposing any retry logic, buffering, or error recovery policies. It serves as the lowest layer in a layered I/O architecture.

This package is designed for:
- **Library authors** building higher-level I/O abstractions
- **Systems programmers** who need direct kernel access
- **Embedded Swift** applications that cannot use Foundation

swift-kernel is **not** designed for:
- Application developers (use swift-io or Foundation instead)
- Cases where automatic retry on `EINTR` is desired
- High-level file abstractions with buffering

## Package Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Application Layer                   │
│            (swift-io, Foundation, etc.)              │
├─────────────────────────────────────────────────────┤
│                   Policy Layer                       │
│         (retry logic, buffering, async I/O)          │
├─────────────────────────────────────────────────────┤
│               swift-kernel (this package)            │
│       Policy-free syscall wrappers with typed throws │
├─────────────────────────────────────────────────────┤
│                    Operating System                  │
│              (Darwin, Linux, Windows)                │
└─────────────────────────────────────────────────────┘
```

## Design Principles

### No Policy

swift-kernel never:
- Retries on `EINTR` (signal interruption)
- Performs partial reads/writes with retry
- Buffers data internally
- Imposes timeout handling

Higher layers decide these policies based on their semantics.

### No Async Runtime

swift-kernel contains no async/await code. It provides the raw syscall building blocks that async runtimes (like swift-io) build upon.

### No Foundation

swift-kernel has zero Foundation dependencies. It uses:
- Raw buffer pointers for I/O
- `SystemPackage.FilePath` internally (not re-exported)
- Custom error types with platform mappings

This makes it suitable for embedded Swift and other constrained environments.

### Typed Throws

All errors use Swift's typed throws with domain-specific error types:

```swift
// Each domain has its own error type
func open(path: String, mode: Mode, options: Options) throws(Kernel.File.Open.Error) -> Kernel.Descriptor

// Errors carry platform-specific codes
catch let error as Kernel.File.Open.Error {
    switch error {
    case .notFound(let code):
        // code is .posix(ENOENT) or .win32(ERROR_FILE_NOT_FOUND)
    }
}
```

## Platform Support

| Platform | Event API | Async I/O |
|----------|-----------|-----------|
| Darwin (macOS, iOS, tvOS, watchOS) | ``Kernel/Kqueue`` | kqueue |
| Linux | ``Kernel/Event/Poll`` | epoll |
| Linux (kernel 5.1+) | ``Kernel/IOUring`` | io_uring |
| Windows | ``Kernel/IOCP`` | I/O Completion Ports |

## Topics

### Essentials

- ``Kernel``
- ``Kernel/Descriptor``
- ``Kernel/Failure``

### File Operations

- ``Kernel/File``
- ``Kernel/File/Open``
- ``Kernel/File/Handle``
- ``Kernel/File/Clone``
- ``Kernel/Close``

### I/O Operations

- ``Kernel/IO/Read``
- ``Kernel/IO/Write``

### Memory Operations

- ``Kernel/Memory``
- ``Kernel/Memory/Map``

### Locking

- ``Kernel/Lock``

### Event APIs

- ``Kernel/Kqueue``
- ``Kernel/IOUring``
- ``Kernel/IOCP``
- ``Kernel/Event/Poll``

### Threading

- ``Kernel/Thread/Handle``
- ``Kernel/Thread/spawn(_:body:)``

> Executor conformances (`Kernel.Thread.Executor`, `Kernel.Thread.Executor.Sharded`)
> live in swift-executors. Thread-layer compositions (`Kernel.Thread.Synchronization`,
> `Kernel.Thread.Barrier`, `Kernel.Thread.Gate`, `Kernel.Thread.Semaphore`,
> `Kernel.Thread.Worker`, `Kernel.Thread.Pool`) live in swift-threads.

### Conceptual Articles

- <doc:error-model>
- <doc:resource-ownership>
- <doc:event-apis>

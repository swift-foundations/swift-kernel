# Event APIs: kqueue, epoll, io_uring, and IOCP

Understanding platform-native event notification and asynchronous I/O mechanisms.

## Overview

swift-kernel exposes the native event APIs for each platform without abstraction. This allows higher layers to build efficient async runtimes while preserving full access to platform-specific features.

## Reactor vs Proactor

Event APIs fall into two models:

### Reactor Model (Readiness-Based)

The kernel notifies when a descriptor is *ready* for an operation. Your code then performs the I/O:

```
┌──────────┐     ready to read     ┌──────────┐
│  Kernel  │ ────────────────────► │ Your App │
└──────────┘                       └──────────┘
                                         │
                                         │ read(fd, ...)
                                         ▼
                                   ┌──────────┐
                                   │   Data   │
                                   └──────────┘
```

**Platforms:** kqueue (Darwin), epoll (Linux)

### Proactor Model (Completion-Based)

You submit an I/O operation. The kernel notifies when it *completes*:

```
┌──────────┐                       ┌──────────┐
│ Your App │ ──── submit read ───► │  Kernel  │
└──────────┘                       └──────────┘
                                         │
                                         │ (kernel does I/O)
                                         ▼
┌──────────┐   completion + data   ┌──────────┐
│ Your App │ ◄──────────────────── │  Kernel  │
└──────────┘                       └──────────┘
```

**Platforms:** IOCP (Windows), io_uring (Linux)

## Platform APIs

### Darwin: kqueue

``Kernel/Kqueue`` wraps the BSD kqueue event notification mechanism:

```swift
// Create a kqueue
let kq = try Kernel.Kqueue.create()
defer { try? Kernel.Close.close(kq) }

// Register interest in a file descriptor
let event = Kernel.Kqueue.Event(
    ident: UInt(fd.rawValue),
    filter: .read,
    flags: [.add, .enable],
    fflags: [],
    data: 0,
    udata: nil
)
try Kernel.Kqueue.register(kq, events: [event])

// Wait for events
var events = [Kernel.Kqueue.Event](repeating: .init(), count: 64)
let count = try Kernel.Kqueue.poll(kq, into: &events, timeout: .seconds(1))
for i in 0..<count {
    // Use `events[i].ident` (or the equivalent `Kernel.Event.ID`) as a key
    // into your own registration table to look up the original descriptor.
    // Reconstructing a `Kernel.Descriptor` from `events[i].ident` is
    // disallowed: the `~Copyable` descriptor must be held by its original
    // owner across the wait, not rebuilt from a raw identifier.
    let id = Kernel.Event.ID(__unchecked: (), UInt(events[i].ident))
    handle(eventID: id)  // your registry lookup
}
```

### Linux: epoll

``Kernel/Event/Poll`` wraps Linux's epoll interface:

```swift
// Create an epoll instance
let epfd = try Kernel.Event.Poll.create()
defer { try? Kernel.Close.close(epfd) }

// Add a file descriptor
try Kernel.Event.Poll.control(
    epfd,
    operation: .add,
    descriptor: fd,
    events: [.in, .edgeTriggered]
)

// Wait for events
var events = [Kernel.Event.Poll.Event](repeating: .init(), count: 64)
let count = try Kernel.Event.Poll.wait(epfd, events: &events, timeout: 1000)
for i in 0..<count {
    if events[i].events.contains(.in) {
        // Descriptor is ready for reading
    }
}
```

### Linux: io_uring

``Kernel/IOUring`` wraps the io_uring asynchronous I/O interface (kernel 5.1+):

```swift
// Check if io_uring is supported
guard Kernel.IOUring.isSupported else {
    // Fall back to epoll
}

// Create an io_uring instance
var params = Kernel.IOUring.Params()
let ringFd = try Kernel.IOUring.setup(entries: 32, params: &params)
defer { Kernel.IOUring.close(ringFd) }

// Submit a read operation
// (Higher layers handle SQ/CQ ring memory mapping and indexing)
```

### Windows: IOCP

``Kernel/IOCP`` wraps I/O Completion Ports:

```swift
// Create a completion port
let port = try Kernel.IOCP.create(concurrentThreads: 0)
defer { try? Kernel.Close.close(port) }

// Associate a file handle (must be opened with FILE_FLAG_OVERLAPPED)
try Kernel.IOCP.associate(port, fileHandle: handle, key: .init(rawValue: 1))

// Initiate an async read
var overlapped = OVERLAPPED()
let result = try Kernel.IOCP.read(handle, into: buffer, overlapped: &overlapped)
switch result {
case .pending:
    // Wait for completion
    let entry = try Kernel.IOCP.Dequeue.one(port, timeout: .infinite)
    let bytesRead = entry.bytesTransferred
case .completed(let bytes):
    // Completed synchronously
    let bytesRead = bytes
}
```

## Choosing an Event API

| Scenario | Darwin | Linux | Windows |
|----------|--------|-------|---------|
| General async I/O | kqueue | epoll | IOCP |
| High-throughput I/O | kqueue | io_uring | IOCP |
| Network servers | kqueue | epoll | IOCP |
| File I/O | kqueue | io_uring | IOCP |

### When to Use io_uring

io_uring provides significant benefits for:
- **High-throughput file I/O** - true async file operations
- **Batched operations** - submit multiple ops with single syscall
- **Zero-copy networking** - with registered buffers

Check availability at runtime:

```swift
if Kernel.IOUring.isSupported {
    // Use io_uring
} else {
    // Fall back to epoll
}
```

### Platform Detection

```swift
#if canImport(Darwin)
    // Use Kernel.Kqueue
#elseif os(Linux)
    if Kernel.IOUring.isSupported {
        // Use Kernel.IOUring
    } else {
        // Use Kernel.Event.Poll (epoll)
    }
#elseif os(Windows)
    // Use Kernel.IOCP
#endif
```

## Topics

### Darwin

- ``Kernel/Kqueue``
- ``Kernel/Kqueue/Event``
- ``Kernel/Kqueue/Filter``
- ``Kernel/Kqueue/Flags``

### Linux (epoll)

- ``Kernel/Event/Poll``
- ``Kernel/Event/Poll/Events``
- ``Kernel/Event/Poll/Operation``

### Linux (io_uring)

- ``Kernel/IOUring``
- ``Kernel/IOUring/Opcode``
- ``Kernel/IOUring/Setup/Flags``

### Windows

- ``Kernel/IOCP``
- ``Kernel/IOCP/Entry``
- ``Kernel/IOCP/Overlapped``

//
//  Kernel.Readiness.Driver+Epoll.swift
//  swift-kernel
//
//  Epoll-backed readiness driver for Linux platforms.
//
//  Implements all 7 policy invariants:
//  INV-1: Registration Identity (atomic counter, non-zero)
//  INV-2: Ownership Lifecycle (consuming dup, close on deregister)
//  INV-3: Delta Correctness (EPOLL_CTL_MOD replaces full interest set)
//  INV-4: One-Shot Re-Arm (EPOLLONESHOT auto-disable)
//  INV-5: Normalization (epoll events/flags → Kernel.Event)
//  INV-6: Staleness Suppression (registry lookup in poll)
//  INV-7: Wake Responsiveness (eventfd trigger)
//

#if os(Linux)

@_spi(Syscall) import Kernel_Primitives
@_spi(Syscall) import Linux_Kernel_Primitives
import Memory_Buffer_Primitives
import Synchronization
import Dictionary_Primitives

// MARK: - Per-Driver State

extension Kernel.Readiness {
    /// Epoll driver namespace.
    enum Epoll {}
}

extension Kernel.Readiness.Epoll {
    /// Shared mutable state for an epoll driver instance.
    ///
    /// Captured by the Driver closures. Thread-safe via Mutex.
    /// Per-instance — each `.epoll()` call creates fresh state.
    final class State: @unchecked Sendable {
        let nextID = Atomic<UInt64>(0)

        let registry = Synchronization.Mutex<
            Dictionary_Primitives.Dictionary<Int32,
                Dictionary_Primitives.Dictionary<Kernel.Event.ID, Kernel.Readiness.Registration.Entry>
            >
        >(.init())

        /// Eventfd wakeup channel descriptor.
        /// Owned by the class — closed deterministically in `_drain`
        /// via nil-assignment (deinit closes the underlying fd).
        nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?

        init(eventfd: consuming Kernel.Event.Descriptor) {
            self.eventfd = consume eventfd
        }
    }
}

// MARK: - Error Conversion

extension Kernel.Readiness.Error {
    init(_ epollError: Kernel.Event.Poll.Error) {
        switch epollError {
        case .create(let code): self = .platform(code)
        case .ctl(let code): self = .platform(code)
        case .wait(let code): self = .platform(code)
        case .interrupted: self = .platform(.POSIX.EINTR)
        }
    }

    init(_ eventfdError: Kernel.Event.Descriptor.Error) {
        switch eventfdError {
        case .create(let code): self = .platform(code)
        case .read(let code): self = .platform(code)
        case .write(let code): self = .platform(code)
        case .wouldBlock: self = .platform(.POSIX.EAGAIN)
        }
    }
}

// MARK: - ID Boundary

extension Kernel.Event.ID {
    /// Decodes a registration ID from epoll poll data.
    ///
    /// Returns nil when the data encodes `.zero` — the sentinel for
    /// non-registration events (wakeup eventfd). Registration IDs are
    /// non-zero by construction (counter starts at 1).
    init?(pollData: Kernel.Event.Poll.Data) {
        guard pollData != .zero else { return nil }
        self = pollData.map { UInt(truncatingIfNeeded: $0) }.retag(Kernel.Event.self)
    }
}

extension Kernel.Event.Poll.Data {
    /// Encodes a registration ID into poll data for the kernel boundary.
    init(registrationID id: Kernel.Event.ID) {
        self = id.map { UInt64($0) }.retag(Kernel.Event.Poll.self)
    }
}

// MARK: - Helpers

extension Kernel.Readiness {
    /// Converts Interest to epoll events with EPOLLONESHOT for one-shot arming.
    private static func epollEvents(oneShot interest: Kernel.Event.Interest) -> Kernel.Event.Poll.Events {
        var events: Kernel.Event.Poll.Events = .et | .oneshot

        if interest.contains(.read) {
            events = events | .in
        }
        if interest.contains(.write) {
            events = events | .out
        }
        if interest.contains(.priority) {
            events = events | .pri
        }

        return events
    }

    /// Converts Kernel.Event.Poll.Events to Interest and Flags.
    private static func normalize(
        _ events: Kernel.Event.Poll.Events
    ) -> (Kernel.Event.Interest, Kernel.Event.Flags) {
        var interest: Kernel.Event.Interest = []
        var flags: Kernel.Event.Flags = []

        if events.contains(.in) { interest.insert(.read) }
        if events.contains(.out) { interest.insert(.write) }
        if events.contains(.pri) { interest.insert(.priority) }

        if events.contains(.err) { flags.insert(.error) }
        if events.contains(.hup) { flags.insert(.hangup) }
        if events.contains(.rdhup) { flags.insert(.readHangup) }

        return (interest, flags)
    }
}

// MARK: - Factory

extension Kernel.Readiness {
    /// Creates an epoll-backed readiness resource.
    ///
    /// Allocates the epoll fd, scratch buffer, eventfd wakeup channel,
    /// and returns a `Readiness` owning all resources. The `Driver` inside
    /// is a pure Copyable witness capturing only the per-instance state.
    public static func epoll() throws(Error) -> Kernel.Readiness {
        // -- Create epoll fd --

        let descriptor: Kernel.Descriptor
        do throws(Kernel.Event.Poll.Error) {
            descriptor = try Kernel.Event.Poll.create()
        } catch {
            throw Error(error)
        }

        let epfd = descriptor._rawValue

        // -- Create eventfd for wakeup --

        var eventfd: Kernel.Event.Descriptor
        do throws(Kernel.Event.Descriptor.Error) {
            eventfd = try Kernel.Event.Descriptor.create(flags: .cloexec | .nonblock)
        } catch {
            throw Error(error)
        }

        // Register eventfd with epoll for read events.
        // data = .zero → wakeup sentinel (no registration ID).
        let wakeupEvent = Kernel.Event.Poll.Event(events: .in | .et)

        do throws(Kernel.Event.Poll.Error) {
            try Kernel.Event.Poll.ctl(
                descriptor, op: .add, fd: eventfd.descriptor, event: wakeupEvent
            )
        } catch {
            throw Error(error)
        }

        // Raw fd for the wakeup closure — the ONE place raw Int32 is acceptable.
        // signal(rawDescriptor:) SPI exists for exactly the ~Copyable-in-Sendable-closure constraint.
        let efd = eventfd.descriptor._rawValue

        // -- Per-instance state --
        // Transfer ~Copyable eventfd ownership to EpollState. The class owns it;
        // _drain sets it to nil for deterministic close via deinit.

        let state = Epoll.State(eventfd: consume eventfd)
        state.registry.withLock { outer in
            outer.set(epfd, .init())
        }

        // -- Allocate scratch buffer --

        let maximum = 256
        let buffer = Memory.Buffer.Mutable.allocate(
            count: Memory.Address.Count(UInt(maximum * MemoryLayout<Kernel.Event.Poll.Event>.stride)),
            alignment: try! Memory.Alignment(MemoryLayout<Kernel.Event.Poll.Event>.alignment)
        )

        // -- Wakeup channel --
        // Captures raw Int32 — can't capture ~Copyable Kernel.Event.Descriptor.
        // Mirrors kqueue's capture of wakeupKq: Int32.

        let wakeup = Wakeup.Channel {
            Kernel.Event.Descriptor.signal(rawDescriptor: efd)
        }

        // -- Build Driver witness --

        let driver = Driver(
            capabilities: Driver.Capabilities(maximum: maximum, triggering: .edge),
            register: {
                (epollFd: borrowing Kernel.Descriptor, descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID in
                let epfd = epollFd._rawValue
                let id = Kernel.Event.ID(__unchecked: (), UInt(truncatingIfNeeded: state.nextID.wrappingAdd(1, ordering: .relaxed).newValue))
                let rawDescriptor = descriptor._rawValue

                var descriptor: Kernel.Descriptor? = consume descriptor

                // Build epoll_event with EPOLLONESHOT for one-shot semantics
                let event = Kernel.Event.Poll.Event(
                    events: epollEvents(oneShot: interest),
                    data: .init(registrationID: id)
                )

                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        epollFd, op: .add, fd: Kernel.Descriptor(_rawValue: rawDescriptor), event: event
                    )
                } catch {
                    try? Kernel.Close.close(descriptor.take()!)
                    throw Error(error)
                }

                try state.registry.withLock { outer throws(Error) in
                    guard var inner = outer.remove(epfd) else {
                        try? Kernel.Close.close(descriptor.take()!)
                        throw .invalidDescriptor
                    }
                    inner.set(id, Registration.Entry(descriptor: descriptor.take()!, interest: interest))
                    outer.set(epfd, consume inner)
                }

                return id
            },
            modify: {
                (epollFd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, newInterest: Kernel.Event.Interest) throws(Error) in
                let epfd = epollFd._rawValue

                let rawDescriptor: Int32? = state.registry.withLock { outer in
                    outer.withValue(forKey: epfd) { inner in
                        inner.withValue(forKey: id) { entry in
                            entry.descriptor._rawValue
                        }
                    } ?? nil
                }

                guard let rawDescriptor else { throw .notRegistered }

                // Build new epoll_event — EPOLLONESHOT replaces the full interest set
                let event = Kernel.Event.Poll.Event(
                    events: epollEvents(oneShot: newInterest),
                    data: .init(registrationID: id)
                )

                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        epollFd, op: .modify, fd: Kernel.Descriptor(_rawValue: rawDescriptor), event: event
                    )
                } catch {
                    throw Error(error)
                }

                state.registry.withLock { outer in
                    if var inner = outer.remove(epfd) {
                        if var entry = inner.remove(id) {
                            entry.interest = newInterest
                            inner.set(id, consume entry)
                        }
                        outer.set(epfd, consume inner)
                    }
                }
            },
            deregister: {
                (epollFd: borrowing Kernel.Descriptor, id: Kernel.Event.ID) throws(Error) in
                let epfd = epollFd._rawValue

                let removedEntry: Registration.Entry? = state.registry.withLock { outer in
                    if var inner = outer.remove(epfd) {
                        let entry = inner.remove(id)
                        outer.set(epfd, consume inner)
                        return entry
                    }
                    return nil
                }

                guard var removedEntry else { return }

                let rawDescriptor = removedEntry.descriptor._rawValue

                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        epollFd, op: .delete, fd: Kernel.Descriptor(_rawValue: rawDescriptor)
                    )
                } catch {
                    // Ignore ENOENT — the fd may have been closed already
                    if case .ctl(let code) = error, code == .POSIX.ENOENT || code == .POSIX.EBADF {
                        // Benign: event auto-removed or fd recycled
                    } else {
                        try? Kernel.Close.close(removedEntry.descriptor)
                        throw Error(error)
                    }
                }

                try? Kernel.Close.close(removedEntry.descriptor)
            },
            arm: {
                (epollFd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Error) in
                let epfd = epollFd._rawValue

                let rawDescriptor: Int32? = state.registry.withLock { outer in
                    outer.withValue(forKey: epfd) { inner in
                        inner.withValue(forKey: id) { entry in
                            entry.descriptor._rawValue
                        }
                    } ?? nil
                }

                guard let rawDescriptor else { throw .notRegistered }

                // Re-arm via EPOLL_CTL_MOD with EPOLLONESHOT
                let event = Kernel.Event.Poll.Event(
                    events: epollEvents(oneShot: interest),
                    data: .init(registrationID: id)
                )

                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        epollFd, op: .modify, fd: Kernel.Descriptor(_rawValue: rawDescriptor), event: event
                    )
                } catch {
                    throw Error(error)
                }
            },
            poll: {
                (epollFd: borrowing Kernel.Descriptor, scratchBuffer: Memory.Buffer.Mutable, deadline: Kernel.Time.Deadline?, buffer: inout [Kernel.Event]) throws(Error) -> Int in

                var duration: Duration? = nil
                if let deadline = deadline {
                    let now = Kernel.Clock.Continuous.now()
                    if now >= deadline.nanoseconds {
                        duration = .zero
                    } else {
                        let remaining = deadline.nanoseconds - now
                        duration = .nanoseconds(Int64(remaining))
                    }
                }

                let epfd = epollFd._rawValue

                // Allocate event buffer for epoll_wait
                var rawEvents = [Kernel.Event.Poll.Event](
                    repeating: Kernel.Event.Poll.Event(events: Kernel.Event.Poll.Events(rawValue: 0)),
                    count: buffer.count
                )

                let count: Int
                do throws(Kernel.Event.Poll.Error) {
                    count = try Kernel.Event.Poll.wait(epollFd, events: &rawEvents, timeout: duration)
                } catch {
                    if case .interrupted = error { return 0 }
                    throw Error(error)
                }

                guard count > 0 else { return 0 }

                // Filter stale events and normalize inside the lock
                return state.registry.withLock { outer in
                    var outputIndex = 0

                    guard let _ = outer.withValue(forKey: epfd, { inner in
                        for i in 0..<count {
                            let raw = rawEvents[i]
                            guard let id = Kernel.Event.ID(pollData: raw.data),
                                  inner.contains(id) else {
                                continue
                            }

                            let (interest, flags) = normalize(raw.events)
                            buffer[outputIndex] = Kernel.Event(id: id, interest: interest, flags: flags)
                            outputIndex += 1
                        }
                    }) else {
                        return 0
                    }

                    return outputIndex
                }
            },
            drain: {
                (epollFd: borrowing Kernel.Descriptor) in
                let epfd = epollFd._rawValue

                // Drain all registration entries (closes dup'd descriptors)
                state.registry.withLock { outer in
                    if var inner = outer.remove(epfd) {
                        inner.drain { _ in }
                    }
                }

                // Close the eventfd — separate fd that must be explicitly closed.
                // (Kqueue's EVFILT_USER dies with the kqueue fd; eventfd does not.)
                // nil-assignment triggers deinit → typed, deterministic close.
                state.eventfd = nil
            }
        )

        return Kernel.Readiness(
            driver: driver,
            descriptor: descriptor,
            buffer: buffer,
            wakeup: wakeup
        )
    }
}

#endif

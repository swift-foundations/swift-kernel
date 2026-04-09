//
//  Kernel.Readiness.Driver+Kqueue.swift
//  swift-kernel
//
//  Kqueue-backed readiness driver for Darwin platforms.
//
//  Implements all 7 policy invariants:
//  INV-1: Registration Identity (atomic counter, non-zero)
//  INV-2: Ownership Lifecycle (consuming dup, close on deregister)
//  INV-3: Delta Correctness (set-difference on modify)
//  INV-4: One-Shot Re-Arm (EV_DISPATCH auto-disable)
//  INV-5: Normalization (kqueue filter/flags → Kernel.Event)
//  INV-6: Staleness Suppression (registry lookup in poll)
//  INV-7: Wake Responsiveness (EVFILT_USER trigger)
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

@_spi(Syscall) import Kernel_Primitives
@_spi(Syscall) import Darwin_Kernel_Primitives
@_spi(Syscall) import Darwin_Kernel_Event_Primitives
import Memory_Buffer_Primitives
import Synchronization
import Dictionary_Primitives

// MARK: - Per-Driver State

extension Kernel.Readiness {
    /// Shared mutable state for a kqueue driver instance.
    ///
    /// Captured by the Driver closures. Thread-safe via Mutex.
    /// Per-instance — each `.kqueue()` call creates fresh state.
    final class KqueueState: @unchecked Sendable {
        let nextID = Atomic<UInt64>(0)

        let registry = Synchronization.Mutex<
            Dictionary_Primitives.Dictionary<Int32,
                Dictionary_Primitives.Dictionary<Kernel.Event.ID, Kernel.Readiness.Registration.Entry>
            >
        >(.init())
    }
}

// MARK: - Error Conversion

extension Kernel.Readiness.Error {
    init(_ kqueueError: Kernel.Kqueue.Error) {
        switch kqueueError {
        case .create(let code): self = .platform(code)
        case .kevent(let code): self = .platform(code)
        case .interrupted: self = .platform(.POSIX.EINTR)
        }
    }
}

// MARK: - Factory

extension Kernel.Readiness {
    /// Creates a kqueue-backed readiness resource.
    ///
    /// Allocates the kqueue fd, scratch buffer, and wakeup channel.
    /// The returned `Readiness` owns all resources; the `Driver` inside
    /// is a pure Copyable witness capturing only the per-instance state.
    public static func kqueue() throws(Error) -> Kernel.Readiness {
        let state = KqueueState()

        // -- Create kqueue fd --

        let descriptor: Kernel.Descriptor
        do throws(Kernel.Kqueue.Error) {
            descriptor = try Kernel.Kqueue.create()
        } catch {
            throw Error(error)
        }

        let kq = descriptor._rawValue
        state.registry.withLock { outer in
            outer.set(kq, .init())
        }

        // -- Allocate scratch buffer --

        let maximum = 256
        let buffer = Memory.Buffer.Mutable.allocate(
            count: Memory.Address.Count(UInt(maximum * MemoryLayout<Kernel.Kqueue.Event>.stride)),
            alignment: try! Memory.Alignment(MemoryLayout<Kernel.Kqueue.Event>.alignment)
        )

        // -- Register EVFILT_USER for wakeup --

        let wakeupEvent = Kernel.Kqueue.Event(
            id: .zero, filter: .user, flags: .add | .clear
        )

        do throws(Kernel.Kqueue.Error) {
            try Kernel.Kqueue.register(descriptor, events: [wakeupEvent])
        } catch {
            throw Error(error)
        }

        let wakeupKq = descriptor._rawValue

        let wakeup = Kernel.Wakeup.Channel {
            let triggerEv = Kernel.Kqueue.Event(
                id: .zero, filter: .user, flags: .none, fflags: .trigger
            )
            do {
                try Kernel.Kqueue.register(rawDescriptor: wakeupKq, events: [triggerEv])
            } catch {
                if case .kevent(let code) = error as? Kernel.Kqueue.Error,
                   code == .POSIX.EBADF || code == .POSIX.ENOENT
                {
                    // Benign: kqueue fd closed or recycled during shutdown
                } else {
                    assertionFailure("wakeup trigger failed: \(error)")
                }
            }
        }

        // -- Build Driver witness --

        let driver = Driver(
            capabilities: Driver.Capabilities(maximum: maximum, triggering: .edge),
            register: {
                (kq: borrowing Kernel.Descriptor, descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID in
                let kqFd = kq._rawValue
                let id = Kernel.Event.ID(__unchecked: (), UInt(truncatingIfNeeded: state.nextID.wrappingAdd(1, ordering: .relaxed).newValue))
                let rawDescriptor = descriptor._rawValue

                var descriptor: Kernel.Descriptor? = consume descriptor

                let addFlags: Kernel.Kqueue.Flags = .add | .clear | .dispatch
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawDescriptor)),
                        filter: .read, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if interest.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawDescriptor)),
                        filter: .write, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                if !events.isEmpty {
                    do throws(Kernel.Kqueue.Error) {
                        try Kernel.Kqueue.register(kq, events: events)
                    } catch {
                        try? Kernel.Close.close(descriptor.take()!)
                        throw Error(error)
                    }
                }

                try state.registry.withLock { outer throws(Error) in
                    guard var inner = outer.remove(kqFd) else {
                        try? Kernel.Close.close(descriptor.take()!)
                        throw .invalidDescriptor
                    }
                    inner.set(id, Registration.Entry(descriptor: descriptor.take()!, interest: interest))
                    outer.set(kqFd, consume inner)
                }

                return id
            },
            modify: {
                (kq: borrowing Kernel.Descriptor, id: Kernel.Event.ID, newInterest: Kernel.Event.Interest) throws(Error) in
                let kqFd = kq._rawValue

                let lookup: (rawDescriptor: Int32, oldInterest: Kernel.Event.Interest)? = state.registry.withLock { outer in
                    outer.withValue(forKey: kqFd) { inner in
                        inner.withValue(forKey: id) { entry in
                            (entry.descriptor._rawValue, entry.interest)
                        }
                    } ?? nil
                }

                guard let lookup else { throw .notRegistered }

                let toAdd = newInterest.subtracting(lookup.oldInterest)
                let toRemove = lookup.oldInterest.subtracting(newInterest)
                var events: [Kernel.Kqueue.Event] = []

                if toRemove.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(lookup.rawDescriptor)),
                        filter: .read, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if toRemove.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(lookup.rawDescriptor)),
                        filter: .write, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                let addFlags: Kernel.Kqueue.Flags = .add | .clear | .dispatch
                if toAdd.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(lookup.rawDescriptor)),
                        filter: .read, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if toAdd.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(lookup.rawDescriptor)),
                        filter: .write, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                if !events.isEmpty {
                    do throws(Kernel.Kqueue.Error) {
                        try Kernel.Kqueue.register(kq, events: events)
                    } catch {
                        throw Error(error)
                    }
                }

                state.registry.withLock { outer in
                    if var inner = outer.remove(kqFd) {
                        if var entry = inner.remove(id) {
                            entry.interest = newInterest
                            inner.set(id, consume entry)
                        }
                        outer.set(kqFd, consume inner)
                    }
                }
            },
            deregister: {
                (kq: borrowing Kernel.Descriptor, id: Kernel.Event.ID) throws(Error) in
                let kqFd = kq._rawValue

                let removedEntry: Registration.Entry? = state.registry.withLock { outer in
                    if var inner = outer.remove(kqFd) {
                        let entry = inner.remove(id)
                        outer.set(kqFd, consume inner)
                        return entry
                    }
                    return nil
                }

                guard var removedEntry else { return }

                let rawDescriptor = removedEntry.descriptor._rawValue
                let interest = removedEntry.interest
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawDescriptor)),
                        filter: .read, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if interest.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawDescriptor)),
                        filter: .write, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                if !events.isEmpty {
                    do throws(Kernel.Kqueue.Error) {
                        try Kernel.Kqueue.register(kq, events: events)
                    } catch {
                        if case .kevent(let code) = error,
                           code == .POSIX.ENOENT || code == .POSIX.EBADF
                        {
                            // Benign: event was auto-removed or fd recycled
                        } else {
                            try? Kernel.Close.close(removedEntry.descriptor)
                            throw Error(error)
                        }
                    }
                }

                try? Kernel.Close.close(removedEntry.descriptor)
            },
            arm: {
                (kq: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Error) in
                let kqFd = kq._rawValue

                let rawDescriptor: Int32? = state.registry.withLock { outer in
                    outer.withValue(forKey: kqFd) { inner in
                        inner.withValue(forKey: id) { entry in
                            entry.descriptor._rawValue
                        }
                    } ?? nil
                }

                guard let rawDescriptor else { throw .notRegistered }

                let armFlags: Kernel.Kqueue.Flags = .add | .enable | .clear | .dispatch
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawDescriptor)),
                        filter: .read, flags: armFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if interest.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawDescriptor)),
                        filter: .write, flags: armFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                guard !events.isEmpty else { return }

                do throws(Kernel.Kqueue.Error) {
                    try Kernel.Kqueue.register(kq, events: events)
                } catch {
                    throw Error(error)
                }
            },
            poll: {
                (kq: borrowing Kernel.Descriptor, scratchBuffer: Memory.Buffer.Mutable, deadline: Kernel.Time.Deadline?, buffer: inout [Kernel.Event]) throws(Error) -> Int in

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

                let kqFd = kq._rawValue

                let count = try unsafe scratchBuffer.withRebound(
                    to: Kernel.Kqueue.Event.self
                ) { (rawEvents: UnsafeMutableBufferPointer<Kernel.Kqueue.Event>) throws(Error) -> Int in
                    do throws(Kernel.Kqueue.Error) {
                        return try Kernel.Kqueue.poll(kq, into: rawEvents, timeout: duration)
                    } catch {
                        if case .interrupted = error { return 0 }
                        throw Error(error)
                    }
                }

                guard count > 0 else { return 0 }

                let collected: [Kernel.Event] = state.registry.withLock { outer in
                    unsafe scratchBuffer.withRebound(
                        to: Kernel.Kqueue.Event.self
                    ) { rawEvents in
                        var events: [Kernel.Event] = []

                        guard let _ = outer.withValue(forKey: kqFd, { inner in
                            for i in 0..<count {
                                let raw = unsafe rawEvents[i]
                                if raw.filter == .user { continue }

                                let id = raw.data.map { UInt(truncatingIfNeeded: $0) }.retag(Kernel.Event.self)
                                guard inner.contains(id) else { continue }

                                var interest: Kernel.Event.Interest = []
                                if raw.filter == .read { interest.insert(.read) }
                                if raw.filter == .write { interest.insert(.write) }

                                var flags: Kernel.Event.Flags = []
                                if raw.flags.contains(.eof) {
                                    flags.insert(.hangup)
                                    if raw.filter == .read { flags.insert(.readHangup) }
                                    else if raw.filter == .write { flags.insert(.writeHangup) }
                                }
                                if raw.flags.contains(.error) { flags.insert(.error) }

                                events.append(Kernel.Event(id: id, interest: interest, flags: flags))
                            }
                        }) else {
                            return []
                        }

                        return events
                    }
                }

                for (i, event) in collected.enumerated() {
                    buffer[i] = event
                }
                return collected.count
            },
            drain: {
                (kq: borrowing Kernel.Descriptor) in
                let kqFd = kq._rawValue
                state.registry.withLock { outer in
                    if var inner = outer.remove(kqFd) {
                        inner.drain { _ in }
                    }
                }
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

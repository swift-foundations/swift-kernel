//
//  Kernel.Event.Source+Epoll.swift
//  swift-kernel
//
//  Epoll-backed event source for Linux platforms.
//
//  Policy invariants implemented by the Driver init (common) and
//  the backend closures below (epoll-specific):
//
//  INV-1: Registration Identity      — Driver init (counter)
//  INV-2: Ownership Lifecycle         — Driver init (registry owns dup'd fd)
//  INV-3: Delta Correctness           — modify below (EPOLL_CTL_MOD replaces full set)
//  INV-4: One-Shot Re-Arm             — add/arm below (EPOLLONESHOT)
//  INV-5: Normalization               — poll below (epoll events → Kernel.Event)
//  INV-6: Staleness Suppression       — Driver init (registry membership check)
//  INV-7: Wake Responsiveness         — factory below (eventfd trigger)
//

#if os(Linux)

@_spi(Syscall) import Kernel_Descriptor_Primitives
@_spi(Syscall) import Kernel_Event_Primitives
@_spi(Syscall) import Kernel_Error_Primitives
@_spi(Syscall) import Linux_Kernel_Primitives

// MARK: - Error Conversion

extension Kernel.Event.Driver.Error {
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
    /// non-registration events (wakeup eventfd).
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

extension Kernel.Event.Source {
    private static func epollEvents(oneShot interest: Kernel.Event.Interest) -> Kernel.Event.Poll.Events {
        var events: Kernel.Event.Poll.Events = [.et, .oneshot]
        if interest.contains(.read) { events.insert(.in) }
        if interest.contains(.write) { events.insert(.out) }
        if interest.contains(.priority) { events.insert(.pri) }
        return events
    }

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

extension Kernel.Event.Source {
    /// Creates an epoll-backed event source.
    public static func epoll() throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {

        // -- Selector fd + eventfd (owned by state, captured by closures) --

        final class Selector {
            let descriptor: Kernel.Descriptor
            // SAFETY: write-once (init), then nil-once (_close). No concurrent
            // access — the driver is thread-confined.
            nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?

            init(descriptor: consuming Kernel.Descriptor, eventfd: consuming Kernel.Event.Descriptor) {
                self.descriptor = descriptor
                self.eventfd = consume eventfd
            }
        }

        let descriptor: Kernel.Descriptor
        do throws(Kernel.Event.Poll.Error) {
            descriptor = try Kernel.Event.Poll.create()
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        var eventfd: Kernel.Event.Descriptor
        do throws(Kernel.Event.Descriptor.Error) {
            eventfd = try Kernel.Event.Descriptor.create(flags: .cloexec | .nonblock)
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        // Register eventfd with epoll (data = .zero → wakeup sentinel).
        let wakeupEvent = Kernel.Event.Poll.Event(events: [.in, .et])
        do throws(Kernel.Event.Poll.Error) {
            try Kernel.Event.Poll.ctl(
                descriptor, op: .add, fd: eventfd.descriptor, event: wakeupEvent
            )
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        let efd = eventfd.descriptor._rawValue
        let selector = Selector(descriptor: consume descriptor, eventfd: consume eventfd)

        // -- Wakeup --

        let wakeup = Kernel.Wakeup.Channel {
            Kernel.Event.Descriptor.signal(rawDescriptor: efd)
        }

        // -- Build Driver from backend operations --

        let driver = Kernel.Event.Driver(
            add: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let event = Kernel.Event.Poll.Event(
                    events: epollEvents(oneShot: interest),
                    data: .init(registrationID: id)
                )
                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        selector.descriptor, op: .add, fd: fd, event: event
                    )
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            modify: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, _: Kernel.Event.Interest, new: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let event = Kernel.Event.Poll.Event(
                    events: epollEvents(oneShot: new),
                    data: .init(registrationID: id)
                )
                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        selector.descriptor, op: .modify, fd: fd, event: event
                    )
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            remove: {
                (fd: borrowing Kernel.Descriptor, _: Kernel.Event.ID, _: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        selector.descriptor, op: .delete, fd: fd
                    )
                } catch {
                    if case .ctl(let code) = error,
                       code == .POSIX.ENOENT || code == .POSIX.EBADF
                    {
                        return // Benign: event auto-removed or fd recycled
                    }
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            arm: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let event = Kernel.Event.Poll.Event(
                    events: epollEvents(oneShot: interest),
                    data: .init(registrationID: id)
                )
                do throws(Kernel.Event.Poll.Error) {
                    try Kernel.Event.Poll.ctl(
                        selector.descriptor, op: .modify, fd: fd, event: event
                    )
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            poll: {
                (timeout: Duration?, maxEvents: Int) throws(Kernel.Event.Driver.Error) -> [Kernel.Event] in

                var rawEvents = Swift.Array<Kernel.Event.Poll.Event>(
                    repeating: Kernel.Event.Poll.Event(events: Kernel.Event.Poll.Events(rawValue: 0)),
                    count: maxEvents
                )

                let count: Int
                do throws(Kernel.Event.Poll.Error) {
                    count = try Kernel.Event.Poll.wait(
                        selector.descriptor, events: &rawEvents, timeout: timeout
                    )
                } catch {
                    if case .interrupted = error { return [] }
                    throw Kernel.Event.Driver.Error(error)
                }

                guard count > 0 else { return [] }

                var events: [Kernel.Event] = []
                for i in 0..<count {
                    let raw = rawEvents[i]
                    guard let id = Kernel.Event.ID(pollData: raw.data) else { continue }
                    let (interest, flags) = normalize(raw.events)
                    events.append(Kernel.Event(id: id, interest: interest, flags: flags))
                }
                return events
            },
            close: {
                selector.eventfd = nil
                // selector.descriptor deinit closes the epoll fd when
                // Selector is deallocated after all closures are dropped.
            }
        )

        return Kernel.Event.Source(driver: driver, wakeup: wakeup)
    }
}

#endif

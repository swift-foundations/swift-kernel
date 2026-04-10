//
//  Kernel.Event.Source+Epoll.swift
//  swift-kernel
//
//  Epoll-backed event source for Linux platforms.
//
//  Three-boundary polling model:
//    Backend (this file): raw epoll event → Kernel.Event translation
//    Driver.init:         staleness suppression via registry membership
//    Caller:              consumes valid events
//
//  Policy invariants:
//    INV-1: Registration Identity      — Driver.init (counter)
//    INV-2: Ownership Lifecycle         — Driver.init (registry owns dup'd fd)
//    INV-3: Delta Correctness           — modify below (EPOLL_CTL_MOD replaces full set)
//    INV-4: One-Shot Re-Arm             — add/arm below (EPOLLONESHOT)
//    INV-5: Normalization               — poll below (epoll events → Kernel.Event)
//    INV-6: Staleness Suppression       — Driver.init (registry membership check)
//    INV-7: Wake Responsiveness         — factory below (eventfd trigger)
//

#if os(Linux)

import Kernel_Event_Primitives
import Linux_Kernel_Standard

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
    fileprivate static func events(oneShot interest: Kernel.Event.Interest) -> Kernel.Event.Poll.Events {
        var events: Kernel.Event.Poll.Events = [.et, .oneshot]
        if interest.contains(.read) { events.insert(.in) }
        if interest.contains(.write) { events.insert(.out) }
        if interest.contains(.priority) { events.insert(.pri) }
        return events
    }

    fileprivate static func normalize(
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
    ///
    /// - Parameter maxEvents: Maximum events per poll cycle. Controls the
    ///   pre-allocated scratch buffer size. Default: 256.
    public static func epoll(
        maxEvents: Int = 256
    ) throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {

        // -- State class (owns L1 epoll struct + eventfd + scratch buffer) --

        final class State {
            let epoll: Kernel.Event.Poll
            // Write-once (init), then nil-once (_close). No concurrent
            // access — the driver is thread-confined.
            nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?
            var rawEvents: [Kernel.Event.Poll.Event]

            init(
                epoll: consuming Kernel.Event.Poll,
                eventfd: consuming Kernel.Event.Descriptor,
                maxEvents: Int
            ) {
                self.epoll = epoll
                self.eventfd = consume eventfd
                self.rawEvents = Swift.Array<Kernel.Event.Poll.Event>(
                    repeating: Kernel.Event.Poll.Event(events: .init(rawValue: 0)),
                    count: maxEvents
                )
            }
        }

        var epoll: Kernel.Event.Poll
        do throws(Kernel.Event.Poll.Error) {
            epoll = try Kernel.Event.Poll()
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        var eventfd: Kernel.Event.Descriptor
        do throws(Kernel.Event.Descriptor.Error) {
            eventfd = try Kernel.Event.Descriptor.create(flags: .cloexec | .nonblock)
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        // -- Wakeup (eventfd, encapsulated in L1) --

        let wakeup: Kernel.Wakeup.Channel
        do throws(Kernel.Event.Poll.Error) {
            wakeup = try epoll.wakeup(eventfd: eventfd)
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        let state = State(
            epoll: consume epoll,
            eventfd: consume eventfd,
            maxEvents: maxEvents
        )

        // -- Build Driver from backend operations --

        let driver = Kernel.Event.Driver(
            add: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let event = Kernel.Event.Poll.Event(
                    events: events(oneShot: interest),
                    data: .init(registrationID: id)
                )
                do throws(Kernel.Event.Poll.Error) {
                    try state.epoll.add(fd: fd, event: event)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            modify: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, _: Kernel.Event.Interest, new: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let event = Kernel.Event.Poll.Event(
                    events: events(oneShot: new),
                    data: .init(registrationID: id)
                )
                do throws(Kernel.Event.Poll.Error) {
                    try state.epoll.modify(fd: fd, event: event)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            remove: {
                (fd: borrowing Kernel.Descriptor, _: Kernel.Event.ID, _: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                do throws(Kernel.Event.Poll.Error) {
                    try state.epoll.remove(fd: fd)
                } catch {
                    if case .ctl(let code) = error,
                       code == .POSIX.ENOENT || code == .POSIX.EBADF
                    {
                        return // Benign: event auto-removed or fd recycled.
                    }
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            arm: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let event = Kernel.Event.Poll.Event(
                    events: events(oneShot: interest),
                    data: .init(registrationID: id)
                )
                do throws(Kernel.Event.Poll.Error) {
                    try state.epoll.modify(fd: fd, event: event)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            poll: {
                (timeout: Duration?, output: inout [Kernel.Event]) throws(Kernel.Event.Driver.Error) -> Int in

                // Poll epoll into pre-allocated scratch buffer.
                let count: Int
                do throws(Kernel.Event.Poll.Error) {
                    count = try state.epoll.poll(events: &state.rawEvents, timeout: timeout)
                } catch {
                    if case .interrupted = error { return 0 }
                    throw Kernel.Event.Driver.Error(error)
                }

                guard count > 0 else { return 0 }

                // Normalize: raw epoll events → cross-platform Kernel.Event.
                var writeIdx = 0
                for i in 0..<count {
                    let raw = state.rawEvents[i]
                    guard let id = Kernel.Event.ID(pollData: raw.data) else { continue }
                    let (interest, flags) = normalize(raw.events)
                    guard writeIdx < output.count else { break }
                    output[writeIdx] = Kernel.Event(id: id, interest: interest, flags: flags)
                    writeIdx += 1
                }
                return writeIdx
            },
            close: {
                state.eventfd = nil
                // State deinit closes the epoll fd when all closures
                // are dropped and the State class is deallocated.
            }
        )

        return Kernel.Event.Source(driver: driver, wakeup: wakeup)
    }
}

#endif

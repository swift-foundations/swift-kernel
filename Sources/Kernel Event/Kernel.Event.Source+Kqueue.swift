//
//  Kernel.Event.Source+Kqueue.swift
//  swift-kernel
//
//  Kqueue-backed event source for Darwin platforms.
//
//  Policy invariants implemented by the Driver init (common) and
//  the backend closures below (kqueue-specific):
//
//  INV-1: Registration Identity      — Driver init (counter)
//  INV-2: Ownership Lifecycle         — Driver init (registry owns dup'd fd)
//  INV-3: Delta Correctness           — add/modify below (kevent set-difference)
//  INV-4: One-Shot Re-Arm             — add/arm below (EV_DISPATCH)
//  INV-5: Normalization               — poll below (filter/flags → Kernel.Event)
//  INV-6: Staleness Suppression       — Driver init (registry membership check)
//  INV-7: Wake Responsiveness         — factory below (EVFILT_USER trigger)
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

@_spi(Syscall) import Kernel_Descriptor_Primitives
@_spi(Syscall) import Kernel_Event_Primitives
@_spi(Syscall) import Kernel_Error_Primitives
@_spi(Syscall) import Darwin_Kernel_Primitives
@_spi(Syscall) import Darwin_Kernel_Event_Primitives
import Memory_Buffer_Primitives

// MARK: - Error Conversion

extension Kernel.Event.Driver.Error {
    init(_ kqueueError: Kernel.Kqueue.Error) {
        switch kqueueError {
        case .create(let code): self = .platform(code)
        case .kevent(let code): self = .platform(code)
        case .interrupted: self = .platform(.POSIX.EINTR)
        }
    }
}

// MARK: - Factory

extension Kernel.Event.Source {
    /// Creates a kqueue-backed event source.
    public static func kqueue(
        maxEvents: Int = 256
    ) throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {

        // -- Selector fd (owned by the state class, captured by closures) --

        final class Selector {
            let descriptor: Kernel.Descriptor
            init(descriptor: consuming Kernel.Descriptor) {
                self.descriptor = descriptor
            }
        }

        let descriptor: Kernel.Descriptor
        do throws(Kernel.Kqueue.Error) {
            descriptor = try Kernel.Kqueue.create()
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        let selector = Selector(descriptor: consume descriptor)

        // -- Scratch buffer --

        let scratchBuffer = Memory.Buffer.Mutable.allocate(
            count: Memory.Address.Count(UInt(maxEvents * MemoryLayout<Kernel.Kqueue.Event>.stride)),
            alignment: try! Memory.Alignment(MemoryLayout<Kernel.Kqueue.Event>.alignment)
        )

        // -- Wakeup (EVFILT_USER) --

        let wakeupEvent = Kernel.Kqueue.Event(
            id: .zero, filter: .user, flags: .add | .clear
        )
        do throws(Kernel.Kqueue.Error) {
            try Kernel.Kqueue.register(selector.descriptor, events: [wakeupEvent])
        } catch {
            throw Kernel.Event.Driver.Error(error)
        }

        let wakeupFd = selector.descriptor._rawValue
        let wakeup = Kernel.Wakeup.Channel {
            let trigger = Kernel.Kqueue.Event(
                id: .zero, filter: .user, flags: .none, fflags: .trigger
            )
            do throws(Kernel.Kqueue.Error) {
                try Kernel.Kqueue.register(rawDescriptor: wakeupFd, events: [trigger])
            } catch {
                if case .kevent(let code) = error,
                   code == .POSIX.EBADF || code == .POSIX.ENOENT
                {
                    // Benign: kqueue fd closed during shutdown
                } else {
                    assertionFailure("wakeup trigger failed: \(error)")
                }
            }
        }

        // -- Build Driver from backend operations --

        let addFlags: Kernel.Kqueue.Flags = .add | .clear | .dispatch

        let driver = Kernel.Event.Driver(
            add: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let rawFd = fd._rawValue
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .read, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if interest.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .write, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                guard !events.isEmpty else { return }

                do throws(Kernel.Kqueue.Error) {
                    try Kernel.Kqueue.register(selector.descriptor, events: events)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            modify: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, old: Kernel.Event.Interest, new: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let rawFd = fd._rawValue
                let toAdd = new.subtracting(old)
                let toRemove = old.subtracting(new)
                var events: [Kernel.Kqueue.Event] = []

                if toRemove.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .read, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if toRemove.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .write, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                if toAdd.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .read, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if toAdd.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .write, flags: addFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                guard !events.isEmpty else { return }

                do throws(Kernel.Kqueue.Error) {
                    try Kernel.Kqueue.register(selector.descriptor, events: events)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            remove: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let rawFd = fd._rawValue
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .read, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if interest.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .write, flags: .delete,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                guard !events.isEmpty else { return }

                do throws(Kernel.Kqueue.Error) {
                    try Kernel.Kqueue.register(selector.descriptor, events: events)
                } catch {
                    if case .kevent(let code) = error,
                       code == .POSIX.ENOENT || code == .POSIX.EBADF
                    {
                        return // Benign: event auto-removed or fd recycled
                    }
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            arm: {
                (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                let rawFd = fd._rawValue
                let armFlags: Kernel.Kqueue.Flags = .add | .enable | .clear | .dispatch
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .read, flags: armFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }
                if interest.contains(.write) {
                    events.append(Kernel.Kqueue.Event(
                        id: Kernel.Event.ID(__unchecked: (), UInt(rawFd)),
                        filter: .write, flags: armFlags,
                        data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                    ))
                }

                guard !events.isEmpty else { return }

                do throws(Kernel.Kqueue.Error) {
                    try Kernel.Kqueue.register(selector.descriptor, events: events)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }
            },
            poll: {
                (timeout: Duration?, maxEvents: Int) throws(Kernel.Event.Driver.Error) -> [Kernel.Event] in

                let count = try unsafe scratchBuffer.withRebound(
                    to: Kernel.Kqueue.Event.self
                ) { (rawEvents: UnsafeMutableBufferPointer<Kernel.Kqueue.Event>) throws(Kernel.Event.Driver.Error) -> Int in
                    do throws(Kernel.Kqueue.Error) {
                        return try Kernel.Kqueue.poll(selector.descriptor, into: rawEvents, timeout: timeout)
                    } catch {
                        if case .interrupted = error { return 0 }
                        throw Kernel.Event.Driver.Error(error)
                    }
                }

                guard count > 0 else { return [] }

                return unsafe scratchBuffer.withRebound(
                    to: Kernel.Kqueue.Event.self
                ) { rawEvents in
                    var events: [Kernel.Event] = []

                    for i in 0..<count {
                        let raw = unsafe rawEvents[i]
                        if raw.filter == .user { continue }

                        let id = raw.data.map { UInt(truncatingIfNeeded: $0) }.retag(Kernel.Event.self)

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

                    return events
                }
            },
            close: {
                scratchBuffer.deallocate()
                // selector.descriptor deinit closes the kqueue fd when
                // Selector is deallocated after all closures are dropped.
            }
        )

        return Kernel.Event.Source(driver: driver, wakeup: wakeup)
    }
}

#endif

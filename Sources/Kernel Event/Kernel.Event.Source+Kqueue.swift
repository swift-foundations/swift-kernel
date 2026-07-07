//
//  Kernel.Event.Source+Kqueue.swift
//  swift-kernel
//
//  Kqueue-backed event source for Darwin platforms.
//
//  Three-boundary polling model:
//    Backend (this file): raw kqueue event → Kernel.Event translation
//    Driver.init:         staleness suppression via registry membership
//    Caller:              consumes valid events
//
//  Policy invariants:
//    INV-1: Registration Identity      — Driver.init (counter)
//    INV-2: Ownership Lifecycle         — Driver.init (registry owns dup'd fd)
//    INV-3: Delta Correctness           — modify below (kevent set-difference)
//    INV-4: One-Shot Re-Arm             — add/arm below (EV_DISPATCH)
//    INV-5: Normalization               — poll below (filter/flags → Kernel.Event)
//    INV-6: Staleness Suppression       — Driver.init (registry membership check)
//    INV-7: Wake Responsiveness         — factory below (EVFILT_USER trigger)
//

// Windows: the event-driver vocabulary (Kernel.Event.Source: epoll/kqueue)
// is POSIX-only; the Windows analog is the IOCP completion path. Gated
// whole-file to match the IO Events / IO Completions posture — the Windows
// leg never constructs an event reactor.
#if !os(Windows)
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

        import Darwin_Kernel_Event_Standard

        // Wave 3.5-Final-Atomic (2026-05-02): explicit import for Kernel.Descriptor
        // member access (Swift 6.x #MemberImportVisibility post-flip).
        public import POSIX_Kernel_Descriptor

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

        // MARK: - Kevent Construction

        extension Kernel.Event.Source {
            /// Builds kqueue events for each interest bit.
            ///
            /// Kqueue uses per-filter events: each interest (read, write) produces
            /// a separate kevent. The registration ID is encoded in udata for
            /// round-trip through the kernel.
            fileprivate static func kevents(
                fd: borrowing Kernel.Descriptor,
                id: Kernel.Event.ID,
                interest: Kernel.Event.Interest,
                flags: Kernel.Kqueue.Flags
            ) -> [Kernel.Kqueue.Event] {
                var events: [Kernel.Kqueue.Event] = []

                if interest.contains(.read) {
                    events.append(
                        Kernel.Kqueue.Event(
                            id: Kernel.Event.ID(descriptor: fd),
                            filter: .read,
                            flags: flags,
                            data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                        )
                    )
                }
                if interest.contains(.write) {
                    events.append(
                        Kernel.Kqueue.Event(
                            id: Kernel.Event.ID(descriptor: fd),
                            filter: .write,
                            flags: flags,
                            data: id.map { UInt64($0) }.retag(Kernel.Kqueue.Event.self)
                        )
                    )
                }

                return events
            }
        }

        // MARK: - Factory

        extension Kernel.Event.Source {
            /// Creates a kqueue-backed event source.
            ///
            /// - Parameter maxEvents: Maximum events per poll cycle. Controls the
            ///   pre-allocated scratch buffer size. Default: 256.
            public static func kqueue(
                maxEvents: Int = 256
            ) throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {

                // -- State class (owns L1 kqueue struct + scratch buffer) --

                final class State {
                    let kq: Kernel.Kqueue
                    var rawEvents: [Kernel.Kqueue.Event]

                    init(kq: consuming Kernel.Kqueue, maxEvents: Int) {
                        self.kq = kq
                        self.rawEvents = [Kernel.Kqueue.Event](
                            repeating: Kernel.Kqueue.Event(id: .zero, filter: .read, flags: .none),
                            count: maxEvents
                        )
                    }
                }

                var kq: Kernel.Kqueue
                do throws(Kernel.Kqueue.Error) {
                    kq = try Kernel.Kqueue()
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }

                // -- Wakeup (EVFILT_USER, registered at L2; Channel constructed at L3 site-of-use) --

                let wakeup: Kernel.Wakeup.Channel
                do throws(Kernel.Kqueue.Error) {
                    let signal = try kq.wakeup()
                    wakeup = Kernel.Wakeup.Channel(signal: signal)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }

                let state = State(kq: consume kq, maxEvents: maxEvents)

                // -- Build Driver from backend operations --

                let addFlags: Kernel.Kqueue.Flags = .add | .clear | .dispatch

                let driver = Kernel.Event.Driver(
                    add: {
                        (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                        let events = kevents(fd: fd, id: id, interest: interest, flags: addFlags)
                        guard !events.isEmpty else { return }
                        do throws(Kernel.Kqueue.Error) {
                            try state.kq.register(events: events)
                        } catch {
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    modify: {
                        (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, old: Kernel.Event.Interest, new: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                        let toRemove = old.subtracting(new)
                        let toAdd = new.subtracting(old)
                        var events = kevents(fd: fd, id: id, interest: toRemove, flags: .delete)
                        events.append(contentsOf: kevents(fd: fd, id: id, interest: toAdd, flags: addFlags))
                        guard !events.isEmpty else { return }
                        do throws(Kernel.Kqueue.Error) {
                            try state.kq.register(events: events)
                        } catch {
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    remove: {
                        (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                        let events = kevents(fd: fd, id: id, interest: interest, flags: .delete)
                        guard !events.isEmpty else { return }
                        do throws(Kernel.Kqueue.Error) {
                            try state.kq.register(events: events)
                        } catch {
                            if case .kevent(let code) = error,
                                code == .POSIX.ENOENT || code == .POSIX.EBADF
                            {
                                return  // Benign: event auto-removed or fd recycled.
                            }
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    arm: {
                        (fd: borrowing Kernel.Descriptor, id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Kernel.Event.Driver.Error) in

                        let armFlags: Kernel.Kqueue.Flags = .add | .enable | .clear | .dispatch
                        let events = kevents(fd: fd, id: id, interest: interest, flags: armFlags)
                        guard !events.isEmpty else { return }
                        do throws(Kernel.Kqueue.Error) {
                            try state.kq.register(events: events)
                        } catch {
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    poll: {
                        (deadline: Clock.Continuous.Deadline?, output: inout [Kernel.Event]) throws(Kernel.Event.Driver.Error) -> Int in

                        let timeout = deadline.map { $0.remaining(at: Clock.Continuous.now) }

                        // Poll kqueue into pre-allocated scratch buffer.
                        let count: Int
                        do throws(Kernel.Kqueue.Error) {
                            count = try state.kq.poll(into: &state.rawEvents, timeout: timeout)
                        } catch {
                            if case .interrupted = error { return 0 }
                            throw Kernel.Event.Driver.Error(error)
                        }

                        guard count > 0 else { return 0 }

                        // Normalize: raw kqueue events → cross-platform Kernel.Event.
                        var writeIdx = 0
                        for i in 0..<count {
                            let raw = state.rawEvents[i]
                            if raw.filter == .user { continue }

                            let id = raw.data.map { UInt(truncatingIfNeeded: $0) }.retag(Kernel.Event.self)

                            var interest: Kernel.Event.Interest = []
                            if raw.filter == .read { interest.insert(.read) }
                            if raw.filter == .write { interest.insert(.write) }

                            var flags: Kernel.Event.Options = []
                            if raw.flags.contains(.eof) {
                                flags.insert(.hangup)
                                if raw.filter == .read {
                                    flags.insert(.readHangup)
                                } else if raw.filter == .write {
                                    flags.insert(.writeHangup)
                                }
                            }
                            if raw.flags.contains(.error) { flags.insert(.error) }

                            guard writeIdx < output.count else { break }
                            output[writeIdx] = Kernel.Event(id: id, interest: interest, flags: flags)
                            writeIdx += 1
                        }
                        return writeIdx
                    },
                    close: {
                        // State deinit closes the kqueue fd when all closures
                        // are dropped and the State class is deallocated.
                    }
                )

                return Kernel.Event.Source(driver: driver, wakeup: wakeup)
            }
        }

    #endif
#endif

#if !os(Windows)
    #if os(Linux)

        import Linux_Kernel_Event

        private typealias RawEvent = Linux.Kernel.Event.Poll.Event

        extension Kernel.Event.Driver.Error {
            init(_ epollError: Linux.Kernel.Event.Poll.Error) {
                switch epollError {
                case .create(let code): self = .platform(code)
                case .ctl(let code): self = .platform(code)
                case .wait(let code): self = .platform(code)
                case .interrupted: self = .platform(.POSIX.EINTR)
                }
            }

            init(_ eventfdError: Linux.Kernel.Event.Descriptor.Error) {
                switch eventfdError {
                case .create(let code): self = .platform(code)
                case .read(let code): self = .platform(code)
                case .write(let code): self = .platform(code)
                case .wouldBlock: self = .platform(.POSIX.EAGAIN)
                }
            }
        }

        extension Kernel.Event.ID {

            init?(pollData: Linux.Kernel.Event.Poll.Data) {
                guard pollData != .zero else { return nil }
                self = pollData.map { UInt(truncatingIfNeeded: $0) }.retag(Kernel.Event.self)
            }
        }

        extension Linux.Kernel.Event.Poll.Data {

            init(registrationID id: Kernel.Event.ID) {
                self = id.map { UInt64($0) }.retag(Linux.Kernel.Event.Poll.self)
            }
        }

        extension Linux.Kernel.Event.Interest {

            fileprivate init(_ interest: Kernel.Event.Interest) {
                var projected: Self = []
                if interest.contains(.read) { projected.insert(.read) }
                if interest.contains(.write) { projected.insert(.write) }
                if interest.contains(.priority) { projected.insert(.priority) }
                self = projected
            }
        }

        extension Kernel.Event.Source {

            fileprivate static func events(
                oneShot interest: Kernel.Event.Interest
            ) -> Linux.Kernel.Event.Poll.Events {
                var events = Linux.Kernel.Event.Poll.Events(
                    interest: Linux.Kernel.Event.Interest(interest)
                )
                events.insert(.et)
                events.insert(.oneshot)
                return events
            }

            fileprivate static func normalize(
                _ events: Linux.Kernel.Event.Poll.Events
            ) -> (Kernel.Event.Interest, Kernel.Event.Options) {
                var interest: Kernel.Event.Interest = []
                var flags: Kernel.Event.Options = []
                if events.contains(.in) { interest.insert(.read) }
                if events.contains(.out) { interest.insert(.write) }
                if events.contains(.pri) { interest.insert(.priority) }
                if events.contains(.err) { flags.insert(.error) }
                if events.contains(.hup) { flags.insert(.hangup) }
                if events.contains(.rdhup) { flags.insert(.readHangup) }
                return (interest, flags)
            }
        }

        extension Kernel.Event.Source {

            public static func epoll(
                maxEvents: Int = 256
            ) throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {

                final class State {
                    let epoll: Linux.Kernel.Event.Poll

                    nonisolated(unsafe) var eventfd: Linux.Kernel.Event.Descriptor?
                    var rawEvents: [RawEvent]

                    init(
                        epoll: consuming Linux.Kernel.Event.Poll,
                        eventfd: consuming Linux.Kernel.Event.Descriptor,
                        maxEvents: Int
                    ) {
                        self.epoll = epoll
                        self.eventfd = consume eventfd
                        self.rawEvents = [RawEvent](
                            repeating: RawEvent(events: .init(rawValue: 0)),
                            count: maxEvents
                        )
                    }
                }

                var epoll: Linux.Kernel.Event.Poll
                do throws(Linux.Kernel.Event.Poll.Error) {
                    epoll = try Linux.Kernel.Event.Poll()
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }

                var eventfd: Linux.Kernel.Event.Descriptor
                do throws(Linux.Kernel.Event.Descriptor.Error) {
                    eventfd = try Linux.Kernel.Event.Descriptor.create(flags: .cloexec | .nonblock)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }

                let wakeup: Kernel.Wakeup.Channel
                do throws(Linux.Kernel.Event.Poll.Error) {
                    let signal = try epoll.wakeup(eventfd: eventfd)
                    wakeup = Kernel.Wakeup.Channel(signal: signal)
                } catch {
                    throw Kernel.Event.Driver.Error(error)
                }

                let state = State(
                    epoll: consume epoll,
                    eventfd: consume eventfd,
                    maxEvents: maxEvents
                )

                let driver = Kernel.Event.Driver(
                    add: {
                        (
                            fd: borrowing Kernel.Descriptor,
                            id: Kernel.Event.ID,
                            interest: Kernel.Event.Interest
                        ) throws(Kernel.Event.Driver.Error) in

                        let event = Linux.Kernel.Event.Poll.Event(
                            events: events(oneShot: interest),
                            data: .init(registrationID: id)
                        )
                        do throws(Linux.Kernel.Event.Poll.Error) {
                            try state.epoll.add(fd: fd, event: event)
                        } catch {
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    modify: {
                        (
                            fd: borrowing Kernel.Descriptor,
                            id: Kernel.Event.ID,
                            _: Kernel.Event.Interest,
                            new: Kernel.Event.Interest
                        ) throws(Kernel.Event.Driver.Error) in

                        let event = Linux.Kernel.Event.Poll.Event(
                            events: events(oneShot: new),
                            data: .init(registrationID: id)
                        )
                        do throws(Linux.Kernel.Event.Poll.Error) {
                            try state.epoll.modify(fd: fd, event: event)
                        } catch {
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    remove: {
                        (
                            fd: borrowing Kernel.Descriptor,
                            _: Kernel.Event.ID,
                            _: Kernel.Event.Interest
                        ) throws(Kernel.Event.Driver.Error) in

                        do throws(Linux.Kernel.Event.Poll.Error) {
                            try state.epoll.remove(fd: fd)
                        } catch {
                            if case .ctl(let code) = error,
                                code == .POSIX.ENOENT || code == .POSIX.EBADF
                            {
                                return
                            }
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    arm: {
                        (
                            fd: borrowing Kernel.Descriptor,
                            id: Kernel.Event.ID,
                            interest: Kernel.Event.Interest
                        ) throws(Kernel.Event.Driver.Error) in

                        let event = Linux.Kernel.Event.Poll.Event(
                            events: events(oneShot: interest),
                            data: .init(registrationID: id)
                        )
                        do throws(Linux.Kernel.Event.Poll.Error) {
                            try state.epoll.modify(fd: fd, event: event)
                        } catch {
                            throw Kernel.Event.Driver.Error(error)
                        }
                    },
                    poll: {
                        (
                            deadline: Clock.Continuous.Deadline?,
                            output: inout [Kernel.Event]
                        ) throws(Kernel.Event.Driver.Error) -> Int in

                        let timeout = deadline.map { $0.remaining(at: Clock.Continuous.now) }

                        let requestCount = min(state.rawEvents.count, output.count)
                        guard requestCount > 0 else { return 0 }

                        let count: Int
                        do throws(Linux.Kernel.Event.Poll.Error) {
                            if requestCount == state.rawEvents.count {
                                count = try state.epoll.poll(
                                    events: &state.rawEvents,
                                    timeout: timeout
                                )
                            } else {
                                var scratch = Array(state.rawEvents[0..<requestCount])
                                count = try state.epoll.poll(events: &scratch, timeout: timeout)
                                state.rawEvents.replaceSubrange(0..<requestCount, with: scratch)
                            }
                        } catch {
                            if case .interrupted = error { return 0 }
                            throw Kernel.Event.Driver.Error(error)
                        }

                        guard count > 0 else { return 0 }

                        var writeIdx = 0
                        for i in 0..<count {
                            let raw = state.rawEvents[i]
                            guard let id = Kernel.Event.ID(pollData: raw.data) else { continue }
                            let (interest, flags) = normalize(raw.events)
                            guard writeIdx < output.count else { break }
                            output[writeIdx] = Kernel.Event(
                                id: id,
                                interest: interest,
                                flags: flags
                            )
                            writeIdx += 1
                        }
                        return writeIdx
                    },
                    close: {
                        state.eventfd = nil

                    }
                )

                return Kernel.Event.Source(driver: driver, wakeup: wakeup)
            }
        }

    #endif
#endif

#if os(Linux)

    import Kernel_Core

    import Kernel_Event
    import Linux_Kernel_IO_Uring

    extension Kernel.Completion.Error {
        fileprivate init(_ uringError: Kernel.IO.Uring.Error) {
            switch uringError {
            case .setup(let code): self = .platform(code)
            case .enter(let code): self = .platform(code)
            case .register(let code): self = .platform(code)
            case .interrupted: self = .platform(.POSIX.EINTR)
            }
        }

        fileprivate init(_ wakeupError: Kernel.IO.Uring.Wakeup.Error) {
            switch wakeupError {
            case .eventfd(let code): self = .platform(code)
            case .register(let code): self = .platform(code)
            }
        }
    }

    extension Kernel.IO.Uring.Length {

        fileprivate init(_ count: Memory.Address.Count) {
            let raw = count.underlying.rawValue
            precondition(
                raw <= UInt(UInt32.max),
                "io_uring length exceeds UInt32 range: \(raw)"
            )
            self.init(UInt32(raw))
        }
    }

    extension Kernel.IO.Uring.Offset {

        fileprivate init(_ offset: Kernel.File.Offset?) {
            if let offset {
                self.init(UInt64(bitPattern: offset.underlying))
            } else {
                self.init(UInt64.max)
            }
        }
    }

    extension Kernel.IO.Uring.Operation.Data {

        fileprivate init(_ token: Kernel.Completion.Token) {
            self.init(_unchecked: token.underlying)
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

    private final class UringState {
        private var uring: Kernel.IO.Uring
        private let cqCapacity: Kernel.IO.Uring.Completion.Count

        init(
            uring: consuming Kernel.IO.Uring,
            cqCapacity: Kernel.IO.Uring.Completion.Count
        ) {
            self.uring = consume uring
            self.cqCapacity = cqCapacity
        }
    }

    extension UringState {

        func enqueue(
            _ submission: Kernel.Completion.Submission,
            target: borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) {
            try Self.enqueue(into: &uring, submission, target: target)
        }

        private static func enqueue(
            into uring: inout Kernel.IO.Uring,
            _ submission: Kernel.Completion.Submission,
            target: borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) {
            guard uring.hasCapacity else {
                throw .submissionQueueFull
            }

            let data = Kernel.IO.Uring.Operation.Data(submission.token)
            let uringTarget = Kernel.IO.Uring.Target(descriptor: target)

            switch submission.opcode {
            case .noOperation:
                uring.next.entry.nop(data: data)

            case .read(let address, let length, let offset):
                unsafe uring.next.entry.read(
                    target: uringTarget,
                    buffer: unsafe UnsafeMutableRawPointer(address),
                    length: .init(length),
                    offset: .init(offset),
                    data: data
                )

            case .write(let address, let length, let offset):
                unsafe uring.next.entry.write(
                    target: uringTarget,
                    buffer: unsafe UnsafeRawPointer(address),
                    length: .init(length),
                    offset: .init(offset),
                    data: data
                )

            case .close:
                uring.next.entry.close(target: uringTarget, data: data)

            case .accept:
                uring.next.entry.accept(
                    target: uringTarget,
                    addr: nil,
                    length: nil,
                    flags: [],
                    data: data
                )

            case .synchronize:
                uring.next.entry.fsync(
                    target: uringTarget,
                    datasync: false,
                    data: data
                )

            case .cancel(let targetToken):
                uring.next.entry.cancel(
                    target: Kernel.IO.Uring.Operation.Data(targetToken),
                    data: data
                )

            case .send(let address, let length):
                unsafe uring.next.entry.send(
                    target: uringTarget,
                    buffer: unsafe UnsafeRawPointer(address),
                    length: .init(length),
                    flags: [],
                    data: data
                )

            case .receive(let address, let length):
                unsafe uring.next.entry.recv(
                    target: uringTarget,
                    buffer: unsafe UnsafeMutableRawPointer(address),
                    length: .init(length),
                    flags: [],
                    data: data
                )

            case .connect(let address, let length):
                unsafe uring.next.entry.connect(
                    target: uringTarget,
                    address: UnsafePointer<Kernel.Socket.Address.Storage>(
                        unsafe UnsafeMutableRawPointer(address).assumingMemoryBound(
                            to: Kernel.Socket.Address.Storage.self
                        )
                    ),
                    length: length.underlying.rawValue <= UInt(UInt32.max)
                        ? UInt32(length.underlying.rawValue)
                        : UInt32.max,
                    data: data
                )

            case .readiness(let events):

                uring.next.entry.poll(
                    target: uringTarget,
                    events: Linux.Kernel.Event.Poll.Events(
                        interest: Linux.Kernel.Event.Interest(events)
                    ),
                    multishot: false,
                    trigger: .edge,
                    data: data
                )
            }

            if submission.flags.contains(.linked) {
                uring.next.entry.flags.insert(.ioLink)
            }
            if submission.flags.contains(.drain) {
                uring.next.entry.flags.insert(.ioDrain)
            }
            if submission.flags.contains(.fixedFile) {
                uring.next.entry.flags.insert(.fixedFile)
            }
            if submission.flags.contains(.bufferSelect) {
                uring.next.entry.flags.insert(.bufferSelect)

            }

            uring.advance()
        }

        func flush() throws(Kernel.Completion.Error) -> Kernel.Completion.Submission.Count {
            let flushed = uring.flush()
            guard flushed > .zero else { return .zero }

            do throws(Kernel.IO.Uring.Error) {
                _ = try uring.enter(
                    toSubmit: flushed,
                    minComplete: .zero,
                    flags: []
                )
            } catch {
                throw Kernel.Completion.Error(error)
            }

            return flushed.retag(Kernel.Completion.Submission.self)
        }

        func drain(
            _ visitor: (Kernel.Completion.Event) -> Void
        ) -> Kernel.Completion.Event.Count {
            let l1Count = uring.drain(limit: cqCapacity) { cqe in

                let rawResult: Int32 =
                    if cqe.isSuccess {
                        Int32(cqe.bytes.transferred!)
                    } else {
                        -Int32(cqe.errorNumber!.underlying)
                    }

                visitor(
                    Kernel.Completion.Event(
                        token: cqe.data.retag(Kernel.Completion.self),
                        result: Kernel.Completion.Event.Result(rawValue: rawResult),

                        flags: Kernel.Completion.Event.Flags(rawValue: cqe.flags.rawValue)
                    )
                )
            }
            return l1Count.retag(Kernel.Completion.Event.self)
        }

        func teardown() {

        }
    }

    extension Kernel.Completion {

        public static func iouring(
            entries: Kernel.IO.Uring.Submission.Count = .init(_unchecked: Cardinal(256))
        ) throws(Error) -> Kernel.Completion {

            var params = Kernel.IO.Uring.Params()
            let ring = try createRing(entries: entries, params: &params)

            var wakeupResult: Kernel.IO.Uring.Wakeup.Result
            do throws(Kernel.IO.Uring.Wakeup.Error) {
                wakeupResult = try ring.createWakeup()
            } catch {
                throw Error(error)
            }

            let wakeup = Kernel.Wakeup.Channel(signal: wakeupResult.signal)
            let eventfd = wakeupResult.eventfd()

            let state = UringState(
                uring: consume ring,
                cqCapacity: params.cqEntries
            )

            let driver = Driver(
                submit: {
                    (submission: Submission, target: borrowing Kernel.Descriptor) throws(Error) in
                    try state.enqueue(submission, target: target)
                },
                flush: { () throws(Error) -> Submission.Count in
                    try state.flush()
                },
                drain: { (visitor: (Event) -> Void) -> Event.Count in
                    state.drain(visitor)
                },
                close: {
                    state.teardown()
                },
                overflowCount: { .zero }

            )

            return Kernel.Completion(
                driver: consume driver,
                wakeup: wakeup,
                notification: Notification(descriptor: Kernel.Descriptor(consume eventfd)),
                capabilities: Capabilities(
                    multishot: true,
                    providedBuffers: true
                )
            )
        }

        private static func createRing(
            entries: Kernel.IO.Uring.Submission.Count,
            params: inout Kernel.IO.Uring.Params
        ) throws(Error) -> Kernel.IO.Uring {
            do throws(Kernel.IO.Uring.Error) {
                let fd = try Kernel.IO.Uring.setup(entries: entries, params: &params)
                return try Kernel.IO.Uring(descriptor: consume fd, params: params)
            } catch {
                throw Error(error)
            }
        }
    }

#endif

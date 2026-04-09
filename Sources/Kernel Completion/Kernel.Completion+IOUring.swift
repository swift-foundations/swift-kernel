//
//  Kernel.Completion+IOUring.swift
//  swift-kernel
//
//  io_uring–backed completion driver for Linux.
//
//  Ring encapsulates all shared-memory mechanism. Driver closures
//  are one-line delegations expressing intent, not mechanism.
//

#if os(Linux)

@_spi(Syscall) @_spi(Internal) import Kernel_Core
@_spi(Syscall) import Linux_Kernel_Primitives

// MARK: - Namespace

extension Kernel.Completion {
    /// io_uring driver namespace.
    enum IOUring {}
}

// MARK: - Error Conversion

extension Kernel.Completion.Error {
    init(_ uringError: Kernel.IO.Uring.Error) {
        switch uringError {
        case .setup(let code): self = .platform(code)
        case .enter(let code): self = .platform(code)
        case .register(let code): self = .platform(code)
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

// MARK: - Ring

extension Kernel.Completion.IOUring {
    /// io_uring completion driver ring manager.
    ///
    /// Thin delegation layer over the L1 ``Kernel/IO/Uring/Ring`` which
    /// owns all shared-memory mechanism. This class adds:
    /// - Boundary conversion (platform-agnostic Submission → io_uring SQE)
    /// - CQE → Kernel.Completion.Event normalization
    /// - Eventfd lifecycle for epoll integration
    ///
    /// NOT Sendable — thread-confined to the poll thread.
    /// Captured by non-@Sendable Driver closures.
    final class Ring {

        // MARK: Private State

        /// L1 shared-memory ring (owns mmap'd SQ/CQ regions, deinit unmaps).
        private var uringRing: Kernel.IO.Uring.Ring

        /// Eventfd for epoll integration.
        nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?

        // MARK: Lifecycle

        private init(
            ring: consuming Kernel.IO.Uring.Ring,
            eventfd: consuming Kernel.Event.Descriptor
        ) {
            self.uringRing = consume ring
            self.eventfd = consume eventfd
        }

        /// Create a Ring by delegating mmap to the L1 io_uring Ring.
        static func create(
            descriptor: borrowing Kernel.Descriptor,
            params: Kernel.IO.Uring.Params,
            eventfd: consuming Kernel.Event.Descriptor
        ) throws(Kernel.Completion.Error) -> Ring {
            let uringRing: Kernel.IO.Uring.Ring
            do throws(Kernel.IO.Uring.Error) {
                uringRing = try Kernel.IO.Uring.Ring.create(
                    descriptor: descriptor,
                    params: params
                )
            } catch {
                throw Kernel.Completion.Error(error)
            }

            return Ring(ring: consume uringRing, eventfd: consume eventfd)
        }

        // MARK: Domain Operations

        /// Place an operation in the submission queue.
        ///
        /// Does NOT notify the kernel — call `flush` to submit.
        func enqueue(
            _ submission: Kernel.Completion.Submission,
            target: borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) {
            guard let sqe = unsafe uringRing.nextEntry() else {
                throw .submissionQueueFull
            }
            unsafe fill(sqe, from: submission, target: target)
            uringRing.commitEntry()
        }

        /// Notify the kernel to process accumulated submissions.
        ///
        /// Returns the number of submissions accepted.
        func flush(
            _ ringFd: borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) -> Int {
            let pending = uringRing.pendingSubmissions
            guard pending > 0 else { return 0 }

            let submitted: Int
            do throws(Kernel.IO.Uring.Error) {
                submitted = try Kernel.IO.Uring.enter(
                    ringFd, toSubmit: pending, minComplete: 0, flags: []
                )
            } catch {
                throw Kernel.Completion.Error(error)
            }

            uringRing.resetPending()
            return submitted
        }

        /// Collect completed operations from the completion queue.
        ///
        /// Non-blocking shared-memory read. Returns the number of events harvested.
        func drain(
            into events: inout [Kernel.Completion.Event]
        ) -> Int {
            var count = 0
            _ = uringRing.drainCompletions(limit: events.count) { cqe in
                events[count] = Kernel.Completion.Event(
                    token: Kernel.Completion.Token(cqe.data.rawValue),
                    result: Kernel.Completion.Event.Result(_rawValue: cqe.res),
                    flags: Kernel.Completion.Event.Flags(_rawValue: cqe.flags)
                )
                count += 1
            }
            return count
        }

        /// Close the eventfd.
        ///
        /// The L1 ``Kernel/IO/Uring/Ring`` deinit unmaps all
        /// shared-memory regions when this class deallocates.
        func teardown() {
            eventfd = nil
        }

        // MARK: SQE Filling (private boundary layer)

        /// Fill an SQE from a platform-agnostic Submission.
        ///
        /// All boundary conversions (typed Submission → io_uring SQE)
        /// are encapsulated here. No raw pointer or rawValue access
        /// escapes this method.
        @unsafe
        private func fill(
            _ sqe: UnsafeMutablePointer<Kernel.IO.Uring.Submission.Queue.Entry>,
            from submission: Kernel.Completion.Submission,
            target: borrowing Kernel.Descriptor
        ) {
            let data = Kernel.IO.Uring.Operation.Data(
                __unchecked: (), submission.token.rawValue
            )

            switch submission.opcode {
            case .nop:
                sqe.pointee.prepare.nop(data: data)

            case .read:
                unsafe sqe.pointee.prepare.read(
                    fd: target,
                    buffer: unsafe bufferPointer(submission.address),
                    length: Kernel.IO.Uring.Length(submission.length.rawValue),
                    offset: Kernel.IO.Uring.Offset(submission.offset.rawValue),
                    data: data
                )

            case .write:
                unsafe sqe.pointee.prepare.write(
                    fd: target,
                    buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                    length: Kernel.IO.Uring.Length(submission.length.rawValue),
                    offset: Kernel.IO.Uring.Offset(submission.offset.rawValue),
                    data: data
                )

            case .close:
                sqe.pointee.prepare.close(fd: target, data: data)

            case .accept:
                unsafe sqe.pointee.prepare.accept(
                    fd: target, addr: nil, addrLen: nil, flags: 0, data: data
                )

            case .fsync:
                sqe.pointee.prepare.fsync(fd: target, datasync: false, data: data)

            case .cancel:
                sqe.pointee.prepare.cancel(
                    target: Kernel.IO.Uring.Operation.Data(
                        __unchecked: (), submission.address._rawValue
                    ),
                    data: data
                )

            case .send:
                unsafe sqe.pointee.prepare.send(
                    fd: target,
                    buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                    length: Kernel.IO.Uring.Length(submission.length.rawValue),
                    flags: 0,
                    data: data
                )

            case .recv:
                unsafe sqe.pointee.prepare.recv(
                    fd: target,
                    buffer: unsafe bufferPointer(submission.address),
                    length: Kernel.IO.Uring.Length(submission.length.rawValue),
                    flags: 0,
                    data: data
                )

            case .connect:
                unsafe sqe.pointee.prepare.connect(
                    fd: target,
                    addr: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                    addrLen: submission.length.rawValue,
                    data: data
                )

            default:
                sqe.pointee.prepare.nop(data: data)
            }

            // SQE-level flags
            var sqeFlags = Kernel.IO.Uring.Submission.Queue.Entry.Flags()
            if submission.flags.contains(.bufferSelect) { sqeFlags.insert(.bufferSelect) }
            if submission.flags.contains(.linked) { sqeFlags.insert(.ioLink) }
            if submission.flags.contains(.fixedFile) { sqeFlags.insert(.fixedFile) }
            sqe.pointee.flags = sqeFlags.rawValue

            // Provided buffer group
            if submission.flags.contains(.bufferSelect) {
                sqe.pointee.buffer = .init(
                    group: Kernel.IO.Uring.Buffer.Group(
                        rawValue: submission.bufferGroup.rawValue
                    )
                )
            }
        }

        /// Reconstruct a buffer pointer from an Address.
        ///
        /// The pointer was validated at Address construction time
        /// (via @unsafe init). This is the single site where
        /// UInt64 → pointer reconstruction occurs.
        @unsafe
        private func bufferPointer(
            _ address: Kernel.Completion.Submission.Address
        ) -> UnsafeMutableRawPointer {
            unsafe UnsafeMutableRawPointer(bitPattern: UInt(address._rawValue))!
        }
    }
}

// MARK: - Factory

extension Kernel.Completion {
    /// Creates an io_uring–backed completion resource.
    ///
    /// Allocates the io_uring ring, mmap's SQ/CQ, creates an eventfd
    /// for epoll integration, and returns a `Completion` owning all resources.
    ///
    /// The eventfd is registered with io_uring so that completions
    /// signal epoll_wait in the IO.Event.Loop — one thread for both
    /// readiness and completion events.
    ///
    /// - Parameter entries: Ring size (rounded up to power of 2 by kernel). Default 256.
    public static func iouring(entries: UInt32 = 256) throws(Error) -> Kernel.Completion {

        // -- Create io_uring ring fd --
        // WHY: Direct return from helper avoids deferred ~Copyable init
        // inside do throws(E) {}, which triggers compiler bug on Swift 6.3 Linux.
        // TRACKING: noncopyable-throwing-init experiment, v7_fix.swift

        var params = Kernel.IO.Uring.Params()
        let descriptor = try createRingDescriptor(entries: entries, params: &params)

        // -- Create eventfd for epoll integration --

        let eventfd = try createEventfd()

        // -- Register eventfd with io_uring --

        let efd = eventfd.descriptor._rawValue
        try registerEventfd(efd, with: descriptor)

        // -- Create Ring (mmap's SQ/CQ regions, owns eventfd) --

        let ring = try IOUring.Ring.create(
            descriptor: descriptor,
            params: params,
            eventfd: consume eventfd
        )

        // -- Wakeup channel --
        // Captures raw Int32 — can't capture ~Copyable Kernel.Event.Descriptor.
        // Same pattern as the epoll driver.

        let wakeup = Kernel.Wakeup.Channel {
            Kernel.Event.Descriptor.signal(rawDescriptor: efd)
        }

        // -- Build Driver witness --
        // Each closure is a one-line delegation to Ring.

        let driver = Driver(
            capabilities: Driver.Capabilities(
                ringSize: Int(params.sqEntries),
                multishot: true,
                providedBuffers: true
            ),
            submit: { (ringFd: borrowing Kernel.Descriptor, targetFd: borrowing Kernel.Descriptor, submission: Submission) throws(Error) in
                try ring.enqueue(submission, target: targetFd)
            },
            flush: { (ringFd: borrowing Kernel.Descriptor) throws(Error) -> Int in
                try ring.flush(ringFd)
            },
            harvest: { (ringFd: borrowing Kernel.Descriptor, deadline: Kernel.Time.Deadline?, events: inout [Event]) throws(Error) -> Int in
                ring.drain(into: &events)
            },
            drain: { (ringFd: borrowing Kernel.Descriptor) in
                ring.teardown()
            }
        )

        return Kernel.Completion(
            driver: driver,
            descriptor: descriptor,
            wakeup: wakeup
        )
    }

    // MARK: - Helpers (avoid deferred ~Copyable init in typed throws)

    /// Acquire the io_uring ring descriptor directly — no deferred init.
    private static func createRingDescriptor(
        entries: UInt32,
        params: inout Kernel.IO.Uring.Params
    ) throws(Error) -> Kernel.Descriptor {
        do throws(Kernel.IO.Uring.Error) {
            return try Kernel.IO.Uring.setup(entries: entries, params: &params)
        } catch {
            throw Error(error)
        }
    }

    /// Acquire the eventfd descriptor directly — no deferred init.
    private static func createEventfd() throws(Error) -> Kernel.Event.Descriptor {
        do throws(Kernel.Event.Descriptor.Error) {
            return try Kernel.Event.Descriptor.create(flags: .cloexec | .nonblock)
        } catch {
            throw Error(error)
        }
    }

    /// Register an eventfd with the io_uring ring.
    private static func registerEventfd(
        _ efd: Int32,
        with descriptor: borrowing Kernel.Descriptor
    ) throws(Error) {
        do throws(Kernel.IO.Uring.Error) {
            var efdRaw = efd
            try withUnsafeMutablePointer(to: &efdRaw) { (ptr: UnsafeMutablePointer<Int32>) throws(Kernel.IO.Uring.Error) in
                try Kernel.IO.Uring.register(
                    descriptor, opcode: .eventfd.register, argument: ptr, count: 1
                )
            }
        } catch {
            throw Error(error)
        }
    }
}

#endif

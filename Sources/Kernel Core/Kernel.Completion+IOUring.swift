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

@_spi(Syscall) @_spi(Internal) import Kernel_Primitives
@_spi(Syscall) import Linux_Kernel_Primitives
import POSIX_Kernel

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

    init(mapping error: Kernel.Memory.Map.Error) {
        switch error {
        case .map(let code), .unmap(let code), .sync(let code), .protect(let code):
            self = .platform(code)
        case .invalid:
            self = .platform(.POSIX.EINVAL)
        }
    }
}

// MARK: - Ring

extension Kernel.Completion.IOUring {
    /// io_uring shared-memory ring manager.
    ///
    /// Encapsulates all ring buffer mechanism: mmap lifecycle,
    /// SQ/CQ index arithmetic, SQE filling, CQE draining.
    ///
    /// NOT Sendable — thread-confined to the poll thread.
    /// Captured by non-@Sendable Driver closures.
    final class Ring {

        // MARK: Private State

        // SQ ring
        private let sqHead: UnsafeMutablePointer<UInt32>
        private let sqTail: UnsafeMutablePointer<UInt32>
        private let sqMask: UInt32
        private let sqEntries: UInt32
        private let sqArray: UnsafeMutablePointer<UInt32>
        private let sqes: UnsafeMutablePointer<Kernel.IO.Uring.Submission.Queue.Entry>

        // CQ ring
        private let cqHead: UnsafeMutablePointer<UInt32>
        private let cqTail: UnsafeMutablePointer<UInt32>
        private let cqMask: UInt32
        private let cqes: UnsafePointer<Kernel.IO.Uring.Completion.Queue.Entry>

        // Submission tracking
        private var pendingCount: UInt32 = 0

        // mmap regions (typed — ecosystem Kernel.Memory.Map handles syscall)
        private let sqRingAddr: Kernel.Memory.Address; private let sqRingSize: Kernel.File.Size
        private let cqRingAddr: Kernel.Memory.Address; private let cqRingSize: Kernel.File.Size
        private let sqeAddr: Kernel.Memory.Address; private let sqeSize: Kernel.File.Size

        // Eventfd for epoll integration
        nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?

        // Teardown guard
        private var tornDown = false

        // MARK: Lifecycle

        private init(
            sqHead: UnsafeMutablePointer<UInt32>,
            sqTail: UnsafeMutablePointer<UInt32>,
            sqMask: UInt32,
            sqEntries: UInt32,
            sqArray: UnsafeMutablePointer<UInt32>,
            sqes: UnsafeMutablePointer<Kernel.IO.Uring.Submission.Queue.Entry>,
            cqHead: UnsafeMutablePointer<UInt32>,
            cqTail: UnsafeMutablePointer<UInt32>,
            cqMask: UInt32,
            cqes: UnsafePointer<Kernel.IO.Uring.Completion.Queue.Entry>,
            sqRingAddr: Kernel.Memory.Address, sqRingSize: Kernel.File.Size,
            cqRingAddr: Kernel.Memory.Address, cqRingSize: Kernel.File.Size,
            sqeAddr: Kernel.Memory.Address, sqeSize: Kernel.File.Size,
            eventfd: consuming Kernel.Event.Descriptor
        ) {
            self.sqHead = sqHead
            self.sqTail = sqTail
            self.sqMask = sqMask
            self.sqEntries = sqEntries
            self.sqArray = sqArray
            self.sqes = sqes
            self.cqHead = cqHead
            self.cqTail = cqTail
            self.cqMask = cqMask
            self.cqes = cqes
            self.sqRingAddr = sqRingAddr; self.sqRingSize = sqRingSize
            self.cqRingAddr = cqRingAddr; self.cqRingSize = cqRingSize
            self.sqeAddr = sqeAddr; self.sqeSize = sqeSize
            self.eventfd = consume eventfd
        }

        deinit { teardown() }

        /// Create a Ring by mmap'ing the io_uring shared-memory regions.
        ///
        /// Uses the ecosystem `Kernel.Memory.Map` (L2 POSIX) to acquire
        /// all mmap regions, then constructs Ring once all succeed.
        /// On partial failure, cleans up acquired regions before throwing.
        ///
        /// NOTE: MAP_POPULATE (Linux prefault hint) is not used — the
        /// POSIX mmap API exposes only portable flags. The kernel faults
        /// pages on first access, which is fine for one-time ring setup.
        static func create(
            descriptor: borrowing Kernel.Descriptor,
            params: Kernel.IO.Uring.Params,
            eventfd: consuming Kernel.Event.Descriptor
        ) throws(Kernel.Completion.Error) -> Ring {
            let sqRingSz = Kernel.File.Size(Int(params.sqOff.array) + Int(params.sqEntries) * MemoryLayout<UInt32>.size)
            let cqRingSz = Kernel.File.Size(Int(params.cqOff.cqes) + Int(params.cqEntries) * MemoryLayout<Kernel.IO.Uring.Completion.Queue.Entry>.size)
            let sqeSz = Kernel.File.Size(Int(params.sqEntries) * MemoryLayout<Kernel.IO.Uring.Submission.Queue.Entry>.size)

            // -- Map SQ ring --

            let sqAddr: Kernel.Memory.Address
            do throws(Kernel.Memory.Map.Error) {
                sqAddr = try Kernel.Memory.Map.map(
                    length: sqRingSz,
                    protection: .readWrite,
                    flags: .shared,
                    fd: descriptor
                )
            } catch {
                throw Kernel.Completion.Error(mapping: error)
            }

            // -- Map CQ ring --

            let cqAddr: Kernel.Memory.Address
            do throws(Kernel.Memory.Map.Error) {
                cqAddr = try Kernel.Memory.Map.map(
                    length: cqRingSz,
                    protection: .readWrite,
                    flags: .shared,
                    fd: descriptor,
                    offset: Kernel.File.Offset(Int(Kernel.IO.Uring.Mmap.Offset.cqRing))
                )
            } catch {
                try? Kernel.Memory.Map.unmap(addr: sqAddr, length: sqRingSz)
                throw Kernel.Completion.Error(mapping: error)
            }

            // -- Map SQE array --

            let sqeAddress: Kernel.Memory.Address
            do throws(Kernel.Memory.Map.Error) {
                sqeAddress = try Kernel.Memory.Map.map(
                    length: sqeSz,
                    protection: .readWrite,
                    flags: .shared,
                    fd: descriptor,
                    offset: Kernel.File.Offset(Int(Kernel.IO.Uring.Mmap.Offset.sqes))
                )
            } catch {
                try? Kernel.Memory.Map.unmap(addr: sqAddr, length: sqRingSz)
                try? Kernel.Memory.Map.unmap(addr: cqAddr, length: cqRingSz)
                throw Kernel.Completion.Error(mapping: error)
            }

            // Extract raw pointers for ring index arithmetic.
            // This is the boundary between typed ecosystem mmap and the
            // raw shared-memory mechanism that io_uring requires.
            let sq = unsafe sqAddr.mutablePointer!
            let cq = unsafe cqAddr.mutablePointer!
            let sqe = unsafe sqeAddress.mutablePointer!

            return Ring(
                sqHead: unsafe sq.advanced(by: Int(params.sqOff.head)).assumingMemoryBound(to: UInt32.self),
                sqTail: unsafe sq.advanced(by: Int(params.sqOff.tail)).assumingMemoryBound(to: UInt32.self),
                sqMask: unsafe sq.advanced(by: Int(params.sqOff.ringMask)).load(as: UInt32.self),
                sqEntries: params.sqEntries,
                sqArray: unsafe sq.advanced(by: Int(params.sqOff.array)).assumingMemoryBound(to: UInt32.self),
                sqes: unsafe sqe.assumingMemoryBound(to: Kernel.IO.Uring.Submission.Queue.Entry.self),
                cqHead: unsafe cq.advanced(by: Int(params.cqOff.head)).assumingMemoryBound(to: UInt32.self),
                cqTail: unsafe cq.advanced(by: Int(params.cqOff.tail)).assumingMemoryBound(to: UInt32.self),
                cqMask: unsafe cq.advanced(by: Int(params.cqOff.ringMask)).load(as: UInt32.self),
                cqes: unsafe UnsafePointer(cq.advanced(by: Int(params.cqOff.cqes))
                    .assumingMemoryBound(to: Kernel.IO.Uring.Completion.Queue.Entry.self)),
                sqRingAddr: sqAddr, sqRingSize: sqRingSz,
                cqRingAddr: cqAddr, cqRingSize: cqRingSz,
                sqeAddr: sqeAddress, sqeSize: sqeSz,
                eventfd: consume eventfd
            )
        }

        // MARK: Domain Operations

        /// Place an operation in the submission queue.
        ///
        /// Does NOT notify the kernel — call `flush` to submit.
        func enqueue(
            _ submission: Kernel.Completion.Submission,
            target: borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) {
            let tail = sqTail.pointee
            guard sqEntries &- (tail &- sqHead.pointee) > 0 else {
                throw .submissionQueueFull
            }

            let idx = Int(tail & sqMask)
            sqArray[idx] = UInt32(idx)
            unsafe fill(sqes.advanced(by: idx), from: submission, target: target)

            // NOTE: io_uring_enter provides a full barrier on flush.
            // WHEN TO REMOVE: add atomic store-release if submissions cross threads.
            sqTail.pointee = tail &+ 1
            pendingCount &+= 1
        }

        /// Notify the kernel to process accumulated submissions.
        ///
        /// Returns the number of submissions accepted.
        func flush(
            _ ringFd: borrowing Kernel.Descriptor
        ) throws(Kernel.Completion.Error) -> Int {
            let pending = pendingCount
            guard pending > 0 else { return 0 }

            let submitted: Int
            do throws(Kernel.IO.Uring.Error) {
                submitted = try Kernel.IO.Uring.enter(
                    ringFd, toSubmit: pending, minComplete: 0, flags: []
                )
            } catch {
                throw Kernel.Completion.Error(error)
            }

            pendingCount = 0
            return submitted
        }

        /// Collect completed operations from the completion queue.
        ///
        /// Non-blocking shared-memory read. Returns the number of events harvested.
        func drain(
            into events: inout [Kernel.Completion.Event]
        ) -> Int {
            var head = cqHead.pointee
            let tail = cqTail.pointee
            var count = 0

            while head != tail, count < events.count {
                let cqe = cqes[Int(head & cqMask)]
                events[count] = Kernel.Completion.Event(
                    token: Kernel.Completion.Token(cqe.data.rawValue),
                    result: Kernel.Completion.Event.Result(_rawValue: cqe.res),
                    flags: Kernel.Completion.Event.Flags(_rawValue: cqe.flags)
                )
                head &+= 1
                count += 1
            }

            // NOTE: io_uring_enter on flush provides barrier for next cycle.
            // WHEN TO REMOVE: add atomic store-release if harvest crosses threads.
            cqHead.pointee = head
            return count
        }

        /// Release all shared-memory regions and close the eventfd.
        func teardown() {
            guard !tornDown else { return }
            try? Kernel.Memory.Map.unmap(addr: sqRingAddr, length: sqRingSize)
            try? Kernel.Memory.Map.unmap(addr: cqRingAddr, length: cqRingSize)
            try? Kernel.Memory.Map.unmap(addr: sqeAddr, length: sqeSize)
            eventfd = nil
            tornDown = true
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

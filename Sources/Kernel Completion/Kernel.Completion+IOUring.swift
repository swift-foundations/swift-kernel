//
//  Kernel.Completion+IOUring.swift
//  swift-kernel
//
//  io_uring–backed completion driver for Linux.
//
//  State class holds the L1 ring struct (which owns its descriptor).
//  Driver closures are one-line delegations expressing intent, not mechanism.
//
//  INV-1: Zero SPI — all platform details encapsulated in L1 typed methods.
//  INV-2: State class is file-private, captured by closures.
//  INV-3: Ring owns descriptor — deinit unmaps regions then closes fd.
//  INV-4: Boundary conversions use .retag() / .map(), not .rawValue.
//

#if os(Linux)

import Kernel_Core
import Linux_Kernel_Primitives

// MARK: - Error Conversion

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

// MARK: - State (INV-2)

/// Factory-local state for the io_uring backend.
///
/// Thread-confined to the event loop thread. Captured by non-`@Sendable`
/// driver closures. NOT `Sendable`.
///
/// The ring owns its descriptor (INV-3) — deinit unmaps SQ/CQ regions
/// then closes the fd. The eventfd descriptor is consumed into
/// ``Kernel/Completion/Notification`` and owned there — not stored here.
private final class UringState {
    /// L1 ring (owns descriptor + mmap'd SQ/CQ regions).
    private var uring: Kernel.IO.Uring

    /// CQ ring capacity — used as drain limit to process all available CQEs.
    private let cqCapacity: Kernel.IO.Uring.Completion.Count

    init(
        uring: consuming Kernel.IO.Uring,
        cqCapacity: Kernel.IO.Uring.Completion.Count
    ) {
        self.uring = consume uring
        self.cqCapacity = cqCapacity
    }

    // MARK: Domain Operations

    /// Place an operation in the submission queue.
    ///
    /// Does NOT notify the kernel — call ``flush()`` to submit.
    func enqueue(
        _ submission: Kernel.Completion.Submission,
        target: borrowing Kernel.Descriptor
    ) throws(Kernel.Completion.Error) {
        guard let sqe = unsafe uring.nextEntry() else {
            throw .submissionQueueFull
        }
        unsafe fill(sqe, from: submission, target: target)
        uring.commitEntry()
    }

    /// Notify the kernel to process accumulated submissions.
    ///
    /// Returns the count of submissions accepted.
    func flush() throws(Kernel.Completion.Error) -> Kernel.Completion.Submission.Count {
        let pending = uring.pendingSubmissions
        guard pending > .zero else { return .zero }

        do throws(Kernel.IO.Uring.Error) {
            _ = try uring.enter(
                toSubmit: pending, minComplete: .zero, flags: []
            )
        } catch {
            throw Kernel.Completion.Error(error)
        }

        uring.resetPending()
        return pending.retag(Kernel.Completion.Submission.self)
    }

    /// Drain completed operations from the completion queue via callback.
    ///
    /// Non-blocking shared-memory read. Advances CQ head as entries are
    /// delivered — this is a protocol action, not ordinary iteration.
    ///
    /// Eventfd acknowledgment is the event loop's responsibility
    /// (it reads the eventfd counter after epoll signals), not ours.
    func drain(
        _ visitor: (Kernel.Completion.Event) -> Void
    ) -> Kernel.Completion.Event.Count {
        let l1Count = uring.drainCompletions(limit: cqCapacity) { cqe in
            visitor(
                Kernel.Completion.Event(
                    token: cqe.data.retag(Kernel.Completion.self),
                    result: Kernel.Completion.Event.Result(rawValue: cqe.res),
                    // WHY: Bit positions are identical — .more (bit 0) = IORING_CQE_F_MORE (bit 1 in
                    // kernel headers, bit 0 after our normalization). If L1 ever renumbers flags,
                    // this pass-through breaks silently. A mapping table would be safer but is
                    // premature with only one flag.
                    flags: Kernel.Completion.Event.Flags(rawValue: cqe.flags.rawValue)
                )
            )
        }
        return l1Count.retag(Kernel.Completion.Event.self)
    }

    /// Tear down state. Class deinit releases uring (unmaps regions, closes fd).
    func teardown() {
        // Intentionally empty — resource cleanup happens through
        // ~Copyable deinit cascade when this class deallocates.
        // The closures that captured `self` are dropped when
        // Driver is consumed, releasing this class's refcount.
    }

    // MARK: SQE Filling (file-private boundary layer)

    /// Fill an SQE from a platform-agnostic Submission (INV-4).
    ///
    /// All boundary conversions (typed Submission → io_uring SQE) are
    /// encapsulated here.
    @unsafe
    private func fill(
        _ sqe: UnsafeMutablePointer<Kernel.IO.Uring.Submission.Queue.Entry>,
        from submission: Kernel.Completion.Submission,
        target: borrowing Kernel.Descriptor
    ) {
        let data = submission.token.retag(Kernel.IO.Uring.Operation.self)

        switch submission.opcode {
        case .nop:
            unsafe sqe.prepare.nop(data: data)

        case .read:
            unsafe sqe.prepare.read(
                fd: target,
                buffer: unsafe bufferPointer(submission.address),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                offset: Kernel.IO.Uring.Offset(submission.offset.rawValue),
                data: data
            )

        case .write:
            unsafe sqe.prepare.write(
                fd: target,
                buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                offset: Kernel.IO.Uring.Offset(submission.offset.rawValue),
                data: data
            )

        case .close:
            unsafe sqe.prepare.close(fd: target, data: data)

        case .accept:
            unsafe sqe.prepare.accept(
                fd: target, addr: nil, addrLen: nil, flags: 0, data: data
            )

        case .fsync:
            unsafe sqe.prepare.fsync(fd: target, datasync: false, data: data)

        case .cancel:
            unsafe sqe.prepare.cancel(
                target: Kernel.IO.Uring.Operation.Data(
                    __unchecked: (), submission.address._rawValue
                ),
                data: data
            )

        case .send:
            unsafe sqe.prepare.send(
                fd: target,
                buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                flags: 0,
                data: data
            )

        case .recv:
            unsafe sqe.prepare.recv(
                fd: target,
                buffer: unsafe bufferPointer(submission.address),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                flags: 0,
                data: data
            )

        case .connect:
            unsafe sqe.prepare.connect(
                fd: target,
                addr: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                addrLen: submission.length.rawValue,
                data: data
            )

        default:
            unsafe sqe.prepare.nop(data: data)
        }

        // SQE-level flags
        var sqeFlags = Kernel.IO.Uring.Submission.Queue.Entry.Flags()
        if submission.flags.contains(.bufferSelect) { sqeFlags.insert(.bufferSelect) }
        if submission.flags.contains(.linked) { sqeFlags.insert(.ioLink) }
        if submission.flags.contains(.fixedFile) { sqeFlags.insert(.fixedFile) }
        sqe.pointee.flags = sqeFlags

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
    /// (via `@unsafe` init). This is the single site where
    /// UInt64 → pointer reconstruction occurs.
    @unsafe
    private func bufferPointer(
        _ address: Kernel.Completion.Submission.Address
    ) -> UnsafeMutableRawPointer {
        unsafe UnsafeMutableRawPointer(bitPattern: UInt(address._rawValue))!
    }
}

// MARK: - Factory

extension Kernel.Completion {
    /// Creates an io_uring–backed completion resource.
    ///
    /// Allocates the io_uring ring, mmap's SQ/CQ, creates an eventfd
    /// for epoll integration, and returns a ``Completion`` owning all
    /// resources.
    ///
    /// The eventfd is registered with io_uring so that completions
    /// signal epoll_wait in the event loop — one thread for both
    /// readiness and completion events.
    ///
    /// - Parameter entries: Ring size (rounded up to power of 2 by kernel).
    ///   Default 256.
    public static func iouring(
        entries: Kernel.IO.Uring.Submission.Count = .init(__unchecked: (), Cardinal(256))
    ) throws(Error) -> Kernel.Completion {

        // -- Create ring (setup fd + mmap SQ/CQ — ring owns descriptor) --
        // WHY: Direct return from helper avoids deferred ~Copyable init
        // inside do throws(E) {}, which triggers compiler bug on Swift 6.3.
        // TRACKING: noncopyable-throwing-init experiment, v7_fix.swift

        var params = Kernel.IO.Uring.Params()
        var ring = try createRing(entries: entries, params: &params)

        // -- Wakeup: eventfd + registration + channel (all L1-local) --

        var wakeupResult: Kernel.IO.Uring.Wakeup.Result
        do throws(Kernel.IO.Uring.Wakeup.Error) {
            wakeupResult = try ring.createWakeup()
        } catch {
            throw Error(error)
        }

        let wakeup = wakeupResult.channel
        let eventfd = wakeupResult.eventfd()

        // -- Create State --

        let state = UringState(
            uring: consume ring,
            cqCapacity: params.cqEntries
        )

        // -- Build Driver witness --
        // Each closure is a one-line delegation to State.

        let driver = Driver(
            submit: { (submission: Submission, target: borrowing Kernel.Descriptor) throws(Error) in
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
            }
        )

        // -- Assemble Completion --
        // Notification owns the eventfd descriptor's lifecycle.

        return Kernel.Completion(
            driver: consume driver,
            wakeup: wakeup,
            notification: Notification(eventfd: consume eventfd),
            capabilities: Capabilities(
                multishot: true,
                providedBuffers: true
            ),
            overflowCount: { .zero }
            // WHEN TO REVISIT: Wire real L1 CQ overflow counter in Commit B
            // after adding cqOverflow pointer to Kernel.IO.Uring struct.
        )
    }

    // MARK: - Helpers (avoid deferred ~Copyable init in typed throws)

    /// Create the ring (setup fd + mmap) — no deferred init.
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

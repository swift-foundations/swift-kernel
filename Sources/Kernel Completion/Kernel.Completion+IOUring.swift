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
import Linux_Kernel_IO_Uring
@_spi(Syscall) import Kernel_Completion_Primitives

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
    /// Fills the current SQE slot from the platform-agnostic Submission,
    /// then advances the tail. Does NOT notify the kernel — call
    /// ``flush()`` to submit.
    func enqueue(
        _ submission: Kernel.Completion.Submission,
        target: borrowing Kernel.Descriptor
    ) throws(Kernel.Completion.Error) {
        guard uring.hasCapacity else {
            throw .submissionQueueFull
        }

        let data = submission.token.retag(Kernel.IO.Uring.Operation.self)

        // Fill the SQE via the Slot coroutine (INV-4).
        // Multiple `uring.next.entry` accesses hit the same slot until advance().
        switch submission.opcode {
        case .nop:
            uring.next.entry.nop(data: data)

        case .read:
            unsafe uring.next.entry.read(
                target: Kernel.IO.Uring.Target(descriptor: target),
                buffer: unsafe bufferPointer(submission.address),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                offset: Kernel.IO.Uring.Offset(submission.offset.rawValue),
                data: data
            )

        case .write:
            unsafe uring.next.entry.write(
                target: Kernel.IO.Uring.Target(descriptor: target),
                buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                offset: Kernel.IO.Uring.Offset(submission.offset.rawValue),
                data: data
            )

        case .close:
            uring.next.entry.close(target: Kernel.IO.Uring.Target(descriptor: target), data: data)

        case .accept:
            uring.next.entry.accept(
                target: Kernel.IO.Uring.Target(descriptor: target), addr: nil, length: nil, flags: [], data: data
            )

        case .fsync:
            uring.next.entry.fsync(target: Kernel.IO.Uring.Target(descriptor: target), datasync: false, data: data)

        case .cancel:
            uring.next.entry.cancel(
                target: Kernel.IO.Uring.Operation.Data(
                    __unchecked: (), submission.cancelTarget!.rawValue
                ),
                data: data
            )

        case .send:
            unsafe uring.next.entry.send(
                target: Kernel.IO.Uring.Target(descriptor: target),
                buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                flags: [],
                data: data
            )

        case .recv:
            unsafe uring.next.entry.recv(
                target: Kernel.IO.Uring.Target(descriptor: target),
                buffer: unsafe bufferPointer(submission.address),
                length: Kernel.IO.Uring.Length(submission.length.rawValue),
                flags: [],
                data: data
            )

        case .connect:
            unsafe uring.next.entry.connect(
                target: Kernel.IO.Uring.Target(descriptor: target),
                address: UnsafePointer<Kernel.Socket.Address.Storage>(
                    unsafe bufferPointer(submission.address).assumingMemoryBound(
                        to: Kernel.Socket.Address.Storage.self
                    )
                ),
                length: submission.length.rawValue,
                data: data
            )

        case .poll:
            // Single-shot POLL_ADD: multishot: false makes the backend
            // produce exactly one CQE when the requested readiness fires,
            // then the registration is dropped. Callers re-submit for
            // subsequent reads. Edge-triggered so the CQE fires on state
            // change, not continuously while the condition holds.
            uring.next.entry.poll(
                target: Kernel.IO.Uring.Target(descriptor: target),
                events: Kernel.Event.Poll.Events(interest: submission.events),
                multishot: false,
                trigger: .edge,
                data: data
            )

        default:
            uring.next.entry.nop(data: data)
        }

        // SQE-level flags (applied after the opcode-specific fill)
        if submission.flags.contains(.linked) {
            uring.next.entry.flags.insert(.ioLink)
        }
        if submission.flags.contains(.fixedFile) {
            uring.next.entry.flags.insert(.fixedFile)
        }
        if submission.flags.contains(.bufferSelect) {
            uring.next.entry.flags.insert(.bufferSelect)
            // FIXME: Buffer group ID requires _bufferGroup (internal to L2).
            // Multishot read/recv overloads handle this internally.
            // For the generic factory path, buffer group selection is deferred
            // until _bufferGroup is promoted to package/public in L2.
        }

        uring.advance()
    }

    /// Notify the kernel to process accumulated submissions.
    ///
    /// Returns the count of submissions accepted.
    func flush() throws(Kernel.Completion.Error) -> Kernel.Completion.Submission.Count {
        let flushed = uring.flush()
        guard flushed > .zero else { return .zero }

        do throws(Kernel.IO.Uring.Error) {
            _ = try uring.enter(
                toSubmit: flushed, minComplete: .zero, flags: []
            )
        } catch {
            throw Kernel.Completion.Error(error)
        }

        return flushed.retag(Kernel.Completion.Submission.self)
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
        let l1Count = uring.drain(limit: cqCapacity) { cqe in
            // Reconstruct raw result from typed CQE API.
            // Success: bytes.transferred gives Int(res) — works for
            // bytes transferred, accept fd, and nop/close (0).
            // Failure: errorNumber gives -res; negate to recover res.
            let rawResult: Int32 = if cqe.isSuccess {
                Int32(cqe.bytes.transferred!)
            } else {
                -Int32(cqe.errorNumber!.rawValue)
            }

            visitor(
                Kernel.Completion.Event(
                    token: cqe.data.retag(Kernel.Completion.self),
                    result: Kernel.Completion.Event.Result(rawValue: rawResult),
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

    // MARK: - Helpers

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
        let ring = try createRing(entries: entries, params: &params)

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
            },
            overflowCount: { .zero }
            // WHEN TO REVISIT: Wire real L1 CQ overflow counter in Commit B
            // after adding cqOverflow pointer to Kernel.IO.Uring struct.
        )

        // -- Assemble Completion --
        // Notification owns the eventfd descriptor's lifecycle.

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

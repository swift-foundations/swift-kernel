//
//  Kernel.Event.Driver.swift
//  swift-kernel
//
//  Witness for event notification backends (kqueue, epoll).
//
//  The init maps backend-specific kernel operations into the full
//  witness, wrapping them with common infrastructure: ID generation,
//  registry management, staleness suppression, and descriptor lifecycle.
//

import Dictionary_Primitives

extension Kernel.Event {
    /// Witness for event notification backends (kqueue, epoll).
    ///
    /// The Driver is a struct of closures capturing backend state.
    /// It is NOT Sendable — transferred to the poll thread via `sending`,
    /// then thread-confined. All access is single-threaded.
    ///
    /// ## Three-Boundary Polling Model
    ///
    /// 1. **Backend**: raw platform event → `Kernel.Event` (translation only)
    /// 2. **Driver**: stale suppression via registry membership (validity filtering)
    /// 3. **Caller**: consumes already-valid events
    ///
    /// No event coalescing — one `Kernel.Event` per delivered readiness record.
    public struct Driver {
        /// Registers a descriptor for event notification.
        ///
        /// Takes consuming ownership of the descriptor. On success, the
        /// registration owns the descriptor (closed on deregister/drain).
        /// On failure, the descriptor is dropped — deinit closes it.
        package let _register: (consuming Kernel.Descriptor, Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID

        /// Updates the registration's configured interest set.
        ///
        /// Does not assert one-shot re-enablement — use `_arm` for that.
        package let _modify: (Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void

        /// Removes a registration. The dup'd descriptor is closed by
        /// `Registration` deinit when the entry drops.
        package let _deregister: (Kernel.Event.ID) throws(Error) -> Void

        /// Re-enables one-shot event delivery for a registration.
        ///
        /// The interest parameter is authoritative — it replaces the armed
        /// interest set, not supplements it. Semantically distinct from
        /// `_modify`: arm re-enables delivery after a one-shot event was
        /// consumed; modify changes what interests are monitored.
        package let _arm: (Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void

        /// Waits for events and writes them into the caller's buffer.
        ///
        /// Writes at most `events.count` valid `Kernel.Event` values into
        /// `events` and returns the number written. Backend translation may
        /// discard backend-local wakeup artifacts; driver filtering may
        /// discard stale registrations.
        package let _poll: (Kernel.Time.Deadline?, inout [Kernel.Event]) throws(Error) -> Int

        /// Drains the registry and cleans up backend resources.
        package let _close: () -> Void
    }
}

// MARK: - Backend Init

extension Kernel.Event.Driver {
    /// Creates a Driver from backend-specific kernel operations.
    ///
    /// The init wraps raw backend operations with common infrastructure:
    /// - **ID generation**: Plain counter on thread-confined state.
    /// - **Registry**: `Dictionary<ID, Registration>` tracking active subscriptions.
    /// - **Staleness suppression**: In-place compaction of poll results by registry membership.
    /// - **Deadline conversion**: `Kernel.Time.Deadline` → `Duration`.
    /// - **Descriptor lifecycle**: Entirely via `~Copyable` deinit — no explicit close calls.
    ///
    /// The Driver is NOT Sendable. After `sending` transfer to the poll thread,
    /// all access is single-threaded. No synchronization is needed.
    ///
    /// - Parameters:
    ///   - add: Register a descriptor+interest with the kernel.
    ///   - modify: Change interest for an existing registration.
    ///     Receives old interest for delta computation (kqueue); epoll ignores it.
    ///   - remove: Remove a registration from the kernel.
    ///     Benign errors (ENOENT, EBADF) should be swallowed.
    ///   - arm: Re-arm a one-shot registration with authoritative interest.
    ///   - poll: Fill the caller's buffer with normalized events. Writes at
    ///     most `output.count` events and returns the count written. Backend
    ///     owns its pre-allocated scratch buffer for raw platform events.
    ///   - close: Clean up backend resources. Called after the registry is drained.
    package init(
        add: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
        modify: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ old: Kernel.Event.Interest, _ new: Kernel.Event.Interest) throws(Error) -> Void,
        remove: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
        arm: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
        poll: @escaping (_ timeout: Duration?, _ output: inout [Kernel.Event]) throws(Error) -> Int,
        close: @escaping () -> Void
    ) {
        // Thread-confined mutable state captured by all witness closures.
        // No synchronization — single-threaded after `sending` transfer.
        final class Shared {
            var nextID = Kernel.Event.ID.zero
            var registry = Dictionary_Primitives.Dictionary<Kernel.Event.ID, Registration>()
        }

        let shared = Shared()

        self._register = {
            (descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID in

            shared.nextID = shared.nextID.map { $0 &+ 1 }
            let id = shared.nextID

            // If add throws, descriptor drops here — deinit closes the fd.
            try add(descriptor, id, interest)

            var box: Kernel.Descriptor? = consume descriptor
            shared.registry.set(id, Registration(descriptor: box.take()!, interest: interest))

            return id
        }

        self._modify = {
            (id: Kernel.Event.ID, newInterest: Kernel.Event.Interest) throws(Error) in

            guard var entry = shared.registry.remove(id) else {
                throw Error.notRegistered
            }
            do throws(Error) {
                try modify(entry.descriptor, id, entry.interest, newInterest)
            } catch {
                shared.registry.set(id, consume entry)
                throw error
            }
            entry.interest = newInterest
            shared.registry.set(id, consume entry)
        }

        self._deregister = {
            (id: Kernel.Event.ID) throws(Error) in

            guard let removed = shared.registry.remove(id) else { return }

            // Backend removes kernel registration; benign errors already swallowed.
            // Registration deinit closes the dup'd descriptor when `removed` drops.
            try remove(removed.descriptor, id, removed.interest)
        }

        self._arm = {
            (id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Error) in

            guard let entry = shared.registry.remove(id) else {
                throw Error.notRegistered
            }
            do throws(Error) {
                try arm(entry.descriptor, id, interest)
            } catch {
                shared.registry.set(id, consume entry)
                throw error
            }
            shared.registry.set(id, consume entry)
        }

        self._poll = {
            (deadline: Kernel.Time.Deadline?, buffer: inout [Kernel.Event]) throws(Error) -> Int in

            // Deadline → duration (common across all backends).
            var duration: Duration? = nil
            if let deadline = deadline {
                let now = Kernel.Clock.Continuous.now()
                if now >= deadline.nanoseconds {
                    duration = .zero
                } else {
                    let remaining = deadline.nanoseconds - now
                    duration = .nanoseconds(Int64(remaining))
                }
            }

            // Backend fills buffer with normalized events.
            let rawCount = try poll(duration, &buffer)
            guard rawCount > 0 else { return 0 }

            // Staleness suppression: in-place compaction by registry membership.
            var write = 0
            for read in 0..<rawCount {
                if shared.registry.contains(buffer[read].id) {
                    if write != read { buffer[write] = buffer[read] }
                    write += 1
                }
            }
            return write
        }

        self._close = {
            shared.registry.drain { _ in }
            close()
        }
    }
}

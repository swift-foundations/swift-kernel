public import Kernel_Descriptor_Primitives

//
//  Kernel.Event.Driver.swift
//  swift-kernel-primitives
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
    /// `~Copyable` — single-ownership, transferred to the poll thread
    /// via `sending`, then thread-confined. All access is single-threaded.
    ///
    /// ## Three-Boundary Polling Model
    ///
    /// 1. **Backend**: raw platform event → `Kernel.Event` (translation only)
    /// 2. **Driver**: stale suppression via registry membership (validity filtering)
    /// 3. **Caller**: consumes already-valid events
    ///
    /// No event coalescing — one `Kernel.Event` per delivered readiness record.
    public struct Driver: ~Copyable {
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
        package let _poll: (Clock.Continuous.Deadline?, inout [Kernel.Event]) throws(Error) -> Int

        /// Drains the registry and cleans up backend resources.
        package let _close: () -> Void

        /// Creates a Driver from backend-specific kernel operations.
        ///
        /// The init wraps raw backend operations with common infrastructure:
        /// - **ID generation**: Plain counter on thread-confined state.
        /// - **Registry**: `Dictionary<ID, Registration>` tracking active subscriptions.
        /// - **Staleness suppression**: In-place compaction of poll results by registry membership.
        /// - **Deadline conversion**: `Clock.Continuous.Deadline` → `Duration`.
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
        ///     The backend is responsible for converting the deadline to its
        ///     native timeout format (clock access is platform-specific).
        ///   - close: Clean up backend resources. Called after the registry is drained.
        public init(
            add: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
            modify: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ old: Kernel.Event.Interest, _ new: Kernel.Event.Interest) throws(Error) -> Void,
            remove: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
            arm: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
            poll: @escaping (_ deadline: Clock.Continuous.Deadline?, _ output: inout [Kernel.Event]) throws(Error) -> Int,
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

                guard var entry = shared.registry.remove(id) else {
                    throw Error.notRegistered
                }
                // Merge with existing armed interest so backends with shared
                // interest masks (epoll EPOLL_CTL_MOD) receive the combined
                // mask. On kqueue, the merge is harmless — the backend creates
                // independent kevents per interest bit.
                entry.armedInterest.formUnion(interest)
                let combined = entry.armedInterest
                do throws(Error) {
                    try arm(entry.descriptor, id, combined)
                } catch {
                    shared.registry.set(id, consume entry)
                    throw error
                }
                shared.registry.set(id, consume entry)
            }

            self._poll = {
                (deadline: Clock.Continuous.Deadline?, buffer: inout [Kernel.Event]) throws(Error) -> Int in

                // Backend fills buffer with normalized events.
                // The backend converts deadline → native timeout (clock access is platform-specific).
                let rawCount = try poll(deadline, &buffer)
                guard rawCount > 0 else { return 0 }

                // Staleness suppression: in-place compaction by registry membership.
                var write = 0
                for read in 0..<rawCount {
                    if shared.registry.contains(buffer[read].id) {
                        if write != read { buffer[write] = buffer[read] }
                        write += 1
                    }
                }

                // Re-arm for residual interests after one-shot delivery.
                //
                // On epoll (EPOLLONESHOT), the kernel disables the entire fd
                // after one event. If a combined interest was armed (e.g.
                // [.read, .write]) but only one direction fired, the other
                // direction must be re-armed or it starves.
                //
                // On kqueue (EV_DISPATCH), each filter is independent — the
                // residual re-arm re-enables an already-enabled filter, which
                // is a kernel no-op. One extra kevent per event under split
                // full-duplex load.
                for i in 0..<write {
                    let event = buffer[i]
                    guard var entry = shared.registry.remove(event.id) else { continue }
                    let residual = entry.armedInterest.subtracting(event.interest)
                    entry.armedInterest = residual
                    if !residual.isEmpty {
                        try? arm(entry.descriptor, event.id, residual)
                    }
                    shared.registry.set(event.id, consume entry)
                }

                return write
            }

            self._close = {
                shared.registry.drain { _ in }
                close()
            }
        }
    }
}


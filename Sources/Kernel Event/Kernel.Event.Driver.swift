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

import Synchronization
import Dictionary_Primitives

extension Kernel.Event {
    /// Witness for event notification backends (kqueue, epoll).
    ///
    /// Closures capture all backend state. The caller never handles
    /// the selector descriptor — it is owned by the captured state.
    public struct Driver {
        package let _register: (consuming Kernel.Descriptor, Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID
        package let _modify: (Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void
        package let _deregister: (Kernel.Event.ID) throws(Error) -> Void
        package let _arm: (Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void
        package let _poll: (Kernel.Time.Deadline?, inout [Kernel.Event]) throws(Error) -> Int
        package let _close: () -> Void
    }
}

// MARK: - Backend Init

extension Kernel.Event.Driver {
    /// Creates a Driver from backend-specific kernel operations.
    ///
    /// The init provides: atomic ID generation, a flat registry
    /// (`Dictionary<ID, Registration>`), staleness suppression in poll,
    /// and deterministic descriptor close on deregister and drain.
    ///
    /// The caller provides: how to talk to the kernel.
    ///
    /// - Parameters:
    ///   - add: Register a descriptor+interest with the kernel. Receives the
    ///     dup'd descriptor (borrowed), the generated ID, and interest.
    ///   - modify: Change interest for an existing registration. Receives the
    ///     descriptor (borrowed), ID, old interest, and new interest. Kqueue
    ///     uses old interest for delta computation; epoll ignores it.
    ///   - remove: Remove a registration from the kernel. Benign errors
    ///     (ENOENT, EBADF) should be swallowed by the closure.
    ///   - arm: Re-arm a one-shot registration.
    ///   - poll: Poll for events. Receives timeout (already converted from
    ///     deadline) and max event count. Returns normalized `Kernel.Event`
    ///     values — staleness suppression is handled by the init.
    ///   - close: Clean up backend resources (scratch buffer, eventfd).
    ///     Called after the registry is drained.
    package init(
        add: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
        modify: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ old: Kernel.Event.Interest, _ new: Kernel.Event.Interest) throws(Error) -> Void,
        remove: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
        arm: @escaping (_ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID, _ interest: Kernel.Event.Interest) throws(Error) -> Void,
        poll: @escaping (_ timeout: Duration?, _ maxEvents: Int) throws(Error) -> [Kernel.Event],
        close: @escaping () -> Void
    ) {
        // Shared state captured by all witness closures.
        final class Shared {
            let nextID = Atomic<UInt64>(0)
            let registry = Synchronization.Mutex<
                Dictionary_Primitives.Dictionary<Kernel.Event.ID, Registration>
            >(.init())
        }

        let shared = Shared()

        self._register = {
            (descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID in

            let id = Kernel.Event.ID(
                __unchecked: (),
                UInt(truncatingIfNeeded: shared.nextID.wrappingAdd(1, ordering: .relaxed).newValue)
            )

            do {
                try add(descriptor, id, interest)
            } catch {
                try? Kernel.Close.close(descriptor)
                throw error
            }

            var box: Kernel.Descriptor? = consume descriptor
            shared.registry.withLock { entries in
                entries.set(id, Registration(descriptor: box.take()!, interest: interest))
            }

            return id
        }

        self._modify = {
            (id: Kernel.Event.ID, newInterest: Kernel.Event.Interest) throws(Error) in

            try shared.registry.withLock { entries throws(Error) in
                guard var entry = entries.remove(id) else {
                    throw Error.notRegistered
                }
                do {
                    try modify(entry.descriptor, id, entry.interest, newInterest)
                } catch {
                    entries.set(id, consume entry)
                    throw error
                }
                entry.interest = newInterest
                entries.set(id, consume entry)
            }
        }

        self._deregister = {
            (id: Kernel.Event.ID) throws(Error) in

            let removed: Registration? = shared.registry.withLock { entries in
                entries.remove(id)
            }

            guard var removed else { return }

            do {
                try remove(removed.descriptor, id, removed.interest)
            } catch {
                try? Kernel.Close.close(removed.descriptor)
                throw error
            }

            try? Kernel.Close.close(removed.descriptor)
        }

        self._arm = {
            (id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Error) in

            try shared.registry.withLock { entries throws(Error) in
                guard var entry = entries.remove(id) else {
                    throw Error.notRegistered
                }
                do {
                    try arm(entry.descriptor, id, interest)
                } catch {
                    entries.set(id, consume entry)
                    throw error
                }
                entries.set(id, consume entry)
            }
        }

        self._poll = {
            (deadline: Kernel.Time.Deadline?, buffer: inout [Kernel.Event]) throws(Error) -> Int in

            // Deadline → duration (common across all backends)
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

            let rawEvents = try poll(duration, buffer.count)
            guard !rawEvents.isEmpty else { return 0 }

            // Staleness suppression: filter by registry membership
            return shared.registry.withLock { entries in
                var count = 0
                for event in rawEvents {
                    guard entries.contains(event.id) else { continue }
                    buffer[count] = event
                    count += 1
                }
                return count
            }
        }

        self._close = {
            shared.registry.withLock { entries in
                entries.drain { _ in }
            }
            close()
        }
    }
}

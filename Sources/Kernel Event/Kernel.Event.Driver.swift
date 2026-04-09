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
    /// The init provides: ID generation, a flat registry
    /// (`Dictionary<ID, Registration>`), staleness suppression in poll,
    /// and deterministic descriptor close on deregister and drain.
    ///
    /// The caller provides: how to talk to the kernel.
    ///
    /// No synchronization: the Driver is NOT Sendable — all access is
    /// single-threaded on the poll thread after `sending` transfer.
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
        // Shared mutable state captured by all witness closures.
        // No synchronization — the Driver is thread-confined after
        // `sending` transfer. All access is from the poll thread.
        final class Shared {
            var nextID = Kernel.Event.ID.zero
            var registry = Dictionary_Primitives.Dictionary<Kernel.Event.ID, Registration>()
        }

        let shared = Shared()

        self._register = {
            (descriptor: consuming Kernel.Descriptor, interest: Kernel.Event.Interest) throws(Error) -> Kernel.Event.ID in

            shared.nextID = shared.nextID.map { $0 &+ 1 }
            let id = shared.nextID

            do throws(Error) {
                try add(descriptor, id, interest)
            } catch {
                try? Kernel.Close.close(descriptor)
                throw error
            }

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

            guard var removed = shared.registry.remove(id) else { return }

            do throws(Error) {
                try remove(removed.descriptor, id, removed.interest)
            } catch {
                try? Kernel.Close.close(removed.descriptor)
                throw error
            }

            try? Kernel.Close.close(removed.descriptor)
        }

        self._arm = {
            (id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Error) in

            guard var entry = shared.registry.remove(id) else {
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
            var count = 0
            for event in rawEvents {
                guard shared.registry.contains(event.id) else { continue }
                buffer[count] = event
                count += 1
            }
            return count
        }

        self._close = {
            shared.registry.drain { _ in }
            close()
        }
    }
}

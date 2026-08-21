#if !os(Windows)
    import Dictionary_Primitives
    import Hash_Indexed_Primitive
    import Hash_Tagged_Primitives
    import Buffer_Primitive
    import Buffer_Linear_Primitive
    import Buffer_Linear_Primitives
    import Storage_Primitive
    import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive

    extension Kernel.Event {

        public struct Driver: ~Copyable {

            package let _register:
                (consuming Kernel.Descriptor, Kernel.Event.Interest) throws(Error) ->
                    Kernel.Event.ID

            package let _modify: (Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void

            package let _deregister: (Kernel.Event.ID) throws(Error) -> Void

            package let _arm: (Kernel.Event.ID, Kernel.Event.Interest) throws(Error) -> Void

            package let _poll:
                (Clock.Continuous.Deadline?, inout [Kernel.Event]) throws(Error) -> Int

            package let _close: () -> Void

            public init(
                add:
                    @escaping (
                        _ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID,
                        _ interest: Kernel.Event.Interest
                    ) throws(Error) -> Void,
                modify:
                    @escaping (
                        _ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID,
                        _ old: Kernel.Event.Interest, _ new: Kernel.Event.Interest
                    ) throws(Error) -> Void,
                remove:
                    @escaping (
                        _ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID,
                        _ interest: Kernel.Event.Interest
                    ) throws(Error) -> Void,
                arm:
                    @escaping (
                        _ fd: borrowing Kernel.Descriptor, _ id: Kernel.Event.ID,
                        _ interest: Kernel.Event.Interest
                    ) throws(Error) -> Void,
                poll:
                    @escaping (
                        _ deadline: Clock.Continuous.Deadline?, _ output: inout [Kernel.Event]
                    ) throws(Error) -> Int,
                close: @escaping () -> Void
            ) {

                final class Shared {

                    typealias Registry = Dictionary_Primitives.Dictionary<
                        Kernel.Event.ID, Registration
                    >
                    var nextID = Kernel.Event.ID.zero
                    var registry = Registry()
                }

                let shared = Shared()

                self._register = {
                    (
                        descriptor: consuming Kernel.Descriptor,
                        interest: Kernel.Event.Interest
                    ) throws(Error) -> Kernel.Event.ID in

                    shared.nextID = shared.nextID.map { $0 &+ 1 }
                    let id = shared.nextID

                    try add(descriptor, id, interest)

                    var box: Kernel.Descriptor? = consume descriptor
                    shared.registry.insert(
                        key: id,
                        value: Registration(descriptor: box.take()!, interest: interest)
                    )

                    return id
                }

                self._modify = {
                    (id: Kernel.Event.ID, newInterest: Kernel.Event.Interest) throws(Error) in

                    guard var entry = shared.registry.removeValue(forKey: id) else {
                        throw Error.notRegistered
                    }
                    do throws(Error) {
                        try modify(entry.descriptor, id, entry.interest, newInterest)
                    } catch {
                        shared.registry.insert(key: id, value: consume entry)
                        throw error
                    }
                    entry.interest = newInterest
                    shared.registry.insert(key: id, value: consume entry)
                }

                self._deregister = {
                    (id: Kernel.Event.ID) throws(Error) in

                    guard let removed = shared.registry.removeValue(forKey: id) else { return }

                    try remove(removed.descriptor, id, removed.interest)
                }

                self._arm = {
                    (id: Kernel.Event.ID, interest: Kernel.Event.Interest) throws(Error) in

                    guard var entry = shared.registry.removeValue(forKey: id) else {
                        throw Error.notRegistered
                    }

                    entry.armedInterest.formUnion(interest)
                    let combined = entry.armedInterest
                    do throws(Error) {
                        try arm(entry.descriptor, id, combined)
                    } catch {
                        shared.registry.insert(key: id, value: consume entry)
                        throw error
                    }
                    shared.registry.insert(key: id, value: consume entry)
                }

                self._poll = {
                    (
                        deadline: Clock.Continuous.Deadline?,
                        buffer: inout [Kernel.Event]
                    ) throws(Error) -> Int in

                    let rawCount = try poll(deadline, &buffer)
                    guard rawCount > 0 else { return 0 }

                    var write = 0
                    for read in 0..<rawCount {
                        if shared.registry.contains(key: buffer[read].id) {
                            if write != read { buffer[write] = buffer[read] }
                            write += 1
                        }
                    }

                    for i in 0..<write {
                        let event = buffer[i]
                        guard var entry = shared.registry.removeValue(forKey: event.id) else {
                            continue
                        }
                        let residual = entry.armedInterest.subtracting(event.interest)
                        entry.armedInterest = residual
                        if !residual.isEmpty {

                            do throws(Error) {
                                try arm(entry.descriptor, event.id, residual)
                            } catch {
                            }
                        }
                        shared.registry.insert(key: event.id, value: consume entry)
                    }

                    return write
                }

                self._close = {
                    shared.registry.removeAll(keepingCapacity: false)
                    close()
                }
            }
        }
    }
#endif

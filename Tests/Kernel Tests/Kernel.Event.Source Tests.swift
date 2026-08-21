import Kernel_Test_Support
import Testing

@testable import Kernel

#if !os(Windows)
    extension Kernel.Event.Source {
        @Suite struct Test {
            @Suite struct Unit {}
            @Suite(
                .disabled(
                    if: Toolchain.hasTaggedMetadataSIGSEGV,

                )
            )
            struct Integration {}
        }
    }
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

    extension Kernel.Event.Source.Test.Integration {
        @Test func `platform creates kqueue source`() throws {
            let source = try Kernel.Event.Source.platform()
            _ = source
        }

        @Test func `kqueue factory creates valid source`() throws {
            let source = try Kernel.Event.Source.kqueue()
            _ = source
        }

        @Test func `kqueue factory accepts custom max events`() throws {
            let source = try Kernel.Event.Source.kqueue(maxEvents: 64)
            _ = source
        }

        @Test func `poll with output buffer smaller than ready registrations does not drop events`()
            throws
        {
            let pipeA = try Kernel.Event.Test.makePipe()
            let pipeB = try Kernel.Event.Test.makePipe()

            let source = try Kernel.Event.Source.kqueue()

            let readA = try Kernel.Descriptor.Duplicate.duplicate(pipeA.read)
            let readB = try Kernel.Descriptor.Duplicate.duplicate(pipeB.read)

            let idA = try source.register(descriptor: readA, interest: .read)
            let idB = try source.register(descriptor: readB, interest: .read)
            try source.arm(id: idA, interest: .read)
            try source.arm(id: idB, interest: .read)

            Kernel.Event.Test.writeByte(pipeA.write)
            Kernel.Event.Test.writeByte(pipeB.write)

            let deadline = Clock.Continuous.Deadline.after(.seconds(2), from: Clock.Continuous.now)

            var first = [Kernel.Event](repeating: .empty, count: 1)
            let firstCount = try source.poll(deadline: deadline, into: &first)
            #expect(firstCount == 1)

            var second = [Kernel.Event](repeating: .empty, count: 1)
            let secondCount = try source.poll(deadline: deadline, into: &second)
            #expect(secondCount == 1)

            let delivered: Swift.Set<Kernel.Event.ID> = [first[0].id, second[0].id]
            #expect(delivered == [idA, idB])

            source.close()
        }
    }

#elseif os(Linux)

    extension Kernel.Event.Source.Test.Integration {
        @Test func `platform creates epoll source`() throws {
            let source = try Kernel.Event.Source.platform()
            _ = source
        }

        @Test func `epoll factory creates valid source`() throws {
            let source = try Kernel.Event.Source.epoll()
            _ = source
        }

        @Test func `epoll factory accepts custom max events`() throws {
            let source = try Kernel.Event.Source.epoll(maxEvents: 64)
            _ = source
        }

        @Test func `poll with output buffer smaller than ready registrations does not drop events`()
            throws
        {
            let pipeA = try Kernel.Event.Test.makePipe()
            let pipeB = try Kernel.Event.Test.makePipe()

            let source = try Kernel.Event.Source.epoll()

            let readA = try Kernel.Descriptor.Duplicate.duplicate(pipeA.read)
            let readB = try Kernel.Descriptor.Duplicate.duplicate(pipeB.read)

            let idA = try source.register(descriptor: readA, interest: .read)
            let idB = try source.register(descriptor: readB, interest: .read)
            try source.arm(id: idA, interest: .read)
            try source.arm(id: idB, interest: .read)

            Kernel.Event.Test.writeByte(pipeA.write)
            Kernel.Event.Test.writeByte(pipeB.write)

            let deadline = Clock.Continuous.Deadline.after(.seconds(2), from: Clock.Continuous.now)

            var first = [Kernel.Event](repeating: .empty, count: 1)
            let firstCount = try source.poll(deadline: deadline, into: &first)
            #expect(firstCount == 1)

            var second = [Kernel.Event](repeating: .empty, count: 1)
            let secondCount = try source.poll(deadline: deadline, into: &second)
            #expect(secondCount == 1)

            let delivered: Swift.Set<Kernel.Event.ID> = [first[0].id, second[0].id]
            #expect(delivered == [idA, idB])

            source.close()
        }
    }

#endif

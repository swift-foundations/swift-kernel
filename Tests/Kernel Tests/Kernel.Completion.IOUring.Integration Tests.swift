#if os(Linux)

    import Testing
    import Kernel_Test_Support
    @_spi(Syscall) @testable import Kernel

    @Suite(.serialized, .enabled(if: Kernel.IO.Uring.isSupported))
    struct `IOUring Integration Tests` {

        @Test func `factory creates valid completion resource`() throws {
            var completion = try Kernel.Completion.iouring()

            let hasNotification = completion.notification != nil
            #expect(hasNotification)

            let multishot = completion.capabilities.multishot
            #expect(multishot)

            let providedBuffers = completion.capabilities.providedBuffers
            #expect(providedBuffers)

            completion.close()
        }

        @Test func `nop submit flush drain round-trip`() throws {
            var completion = try Kernel.Completion.iouring()

            let token = Kernel.Completion.Token(42)
            let submission = Kernel.Completion.Submission(opcode: .noOperation, token: token)
            try completion.submit(submission)

            let flushed = try completion.flush()
            #expect(flushed > .zero)

            var receivedTokens: [Kernel.Completion.Token] = []
            var receivedResults: [Kernel.Completion.Event.Result] = []

            let drained = completion.drain { event in
                receivedTokens.append(event.token)
                receivedResults.append(event.result)
            }

            #expect(drained == 1)
            #expect(receivedTokens.count == 1)
            #expect(receivedTokens[0] == 42)

            let isSuccess = receivedResults[0].isSuccess
            #expect(isSuccess)
            let value = receivedResults[0].value
            #expect(value == 0)

            completion.close()
        }

        @Test func `drain returns correct event count`() throws {
            var completion = try Kernel.Completion.iouring()

            let sub1 = Kernel.Completion.Submission(opcode: .noOperation, token: .init(1))
            let sub2 = Kernel.Completion.Submission(opcode: .noOperation, token: .init(2))
            let sub3 = Kernel.Completion.Submission(opcode: .noOperation, token: .init(3))

            try completion.submit(sub1)
            try completion.submit(sub2)
            try completion.submit(sub3)

            let flushed = try completion.flush()
            #expect(flushed == 3)

            var receivedTokens: Set<UInt64> = []

            let drained = completion.drain { event in
                receivedTokens.insert(event.token.underlying)
            }

            #expect(drained == 3)
            #expect(receivedTokens.count == 3)
            #expect(receivedTokens.contains(1))
            #expect(receivedTokens.contains(2))
            #expect(receivedTokens.contains(3))

            completion.close()
        }

        @Test func `submission with drain flag round-trips through submit flush drain`() throws {
            var completion = try Kernel.Completion.iouring()

            let plain = Kernel.Completion.Submission(opcode: .noOperation, token: .init(10))
            let drained = Kernel.Completion.Submission(
                opcode: .noOperation,
                token: .init(11),
                flags: .drain
            )

            try completion.submit(plain)
            try completion.submit(drained)

            let flushed = try completion.flush()
            #expect(flushed == 2)

            var receivedTokens: Set<UInt64> = []
            let count = completion.drain { event in
                receivedTokens.insert(event.token.underlying)
            }

            #expect(count == 2)
            #expect(receivedTokens == [10, 11])

            completion.close()
        }

        @Test func `close tears down without error`() throws {
            var completion = try Kernel.Completion.iouring()
            completion.close()

        }
    }

#endif

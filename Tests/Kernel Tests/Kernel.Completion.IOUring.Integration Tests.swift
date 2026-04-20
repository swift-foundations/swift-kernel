// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if os(Linux)

import Testing
import Kernel_Test_Support
@_spi(Syscall) @testable import Kernel

// MARK: - io_uring Integration Tests

/// Integration tests exercising the REAL `Kernel.Completion.iouring()` factory
/// against the Linux kernel's io_uring subsystem.
///
/// These tests prove the full lifecycle: factory creation, submission, flush,
/// drain, CQE result reconstruction, and resource teardown.
@Suite(.serialized)
struct `IOUring Integration Tests` {

    // MARK: - Factory

    @Test func `factory creates valid completion resource`() throws {
        var completion = try Kernel.Completion.iouring()

        // io_uring provides an eventfd for epoll integration
        let hasNotification = completion.notification != nil
        #expect(hasNotification)

        // io_uring supports multishot operations (accept, recv)
        let multishot = completion.capabilities.multishot
        #expect(multishot)

        // io_uring supports kernel-managed buffer pools
        let providedBuffers = completion.capabilities.providedBuffers
        #expect(providedBuffers)

        completion.close()
    }

    // MARK: - Submit + Flush + Drain

    @Test func `nop submit flush drain round-trip`() throws {
        var completion = try Kernel.Completion.iouring()

        // Submit a nop with a known token
        let token = Kernel.Completion.Token(42)
        let submission = Kernel.Completion.Submission(opcode: .noOperation, token: token)
        try completion.submit(submission)

        // Flush to kernel — at least one submission accepted
        let flushed = try completion.flush()
        #expect(flushed > .zero)

        // Drain — exactly one completion event
        var receivedTokens: [Kernel.Completion.Token] = []
        var receivedResults: [Kernel.Completion.Event.Result] = []

        let drained = completion.drain { event in
            receivedTokens.append(event.token)
            receivedResults.append(event.result)
        }

        #expect(drained == 1)
        #expect(receivedTokens.count == 1)
        #expect(receivedTokens[0] == 42)

        // nop completes with result 0 (success, no bytes)
        let isSuccess = receivedResults[0].isSuccess
        #expect(isSuccess)
        let value = receivedResults[0].value
        #expect(value == 0)

        completion.close()
    }

    // MARK: - Multiple Submissions

    @Test func `drain returns correct event count`() throws {
        var completion = try Kernel.Completion.iouring()

        // Submit 3 nops with distinct tokens
        let sub1 = Kernel.Completion.Submission(opcode: .noOperation, token: .init(1))
        let sub2 = Kernel.Completion.Submission(opcode: .noOperation, token: .init(2))
        let sub3 = Kernel.Completion.Submission(opcode: .noOperation, token: .init(3))

        try completion.submit(sub1)
        try completion.submit(sub2)
        try completion.submit(sub3)

        let flushed = try completion.flush()
        #expect(flushed == 3)

        // Drain all three
        var receivedTokens: Set<UInt64> = []

        let drained = completion.drain { event in
            receivedTokens.insert(event.token.rawValue)
        }

        #expect(drained == 3)
        #expect(receivedTokens.count == 3)
        #expect(receivedTokens.contains(1))
        #expect(receivedTokens.contains(2))
        #expect(receivedTokens.contains(3))

        completion.close()
    }

    // MARK: - CQE Result Reconstruction

    // TODO: `pipe read produces bytes-transferred result`
    //
    // This test would prove the CQE rawResult reconstruction path for
    // positive bytes-transferred values:
    //   1. Create a pipe (read end + write end)
    //   2. Write known data to the write end
    //   3. Submit a read operation targeting the read end
    //   4. Flush + drain
    //   5. Verify result.isSuccess and result.value == bytes written
    //
    // Deferred: Pipe creation at this layer requires direct syscall
    // access (Kernel.Pipe or POSIX pipe()), and wiring the buffer
    // address through the .read opcode associated values requires
    // @unsafe pointer construction. This is better tested at the IO
    // layer where typed read/write operations exist.

    // MARK: - Close

    @Test func `close tears down without error`() throws {
        var completion = try Kernel.Completion.iouring()
        completion.close()
        // Reaching this line proves close() consumed the resource
        // without trapping. No further assertion needed.
    }
}

#endif

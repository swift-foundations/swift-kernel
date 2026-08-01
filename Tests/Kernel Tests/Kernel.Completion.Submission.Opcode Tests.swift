//
//  Kernel.Completion.Submission.Opcode Tests.swift
//  swift-kernel-primitives
//

// The `.readiness` variant carries `Kernel.Event.Interest`, which the
// vocabulary hoist moved into the `Kernel Event` target. `Kernel_Completion`
// does not re-export it, so the declaring module is imported per-file
// (#MemberImportVisibility).
import Kernel_Event
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import Kernel_Completion

extension Kernel.Completion.Submission.Opcode {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Exhaustiveness` {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Submission.Opcode.Test.Unit {
    @Test
    func `same cancel targets compare equal`() {
        let a: Kernel.Completion.Submission.Opcode = .cancel(target: 42)
        let b: Kernel.Completion.Submission.Opcode = .cancel(target: 42)
        #expect(a == b)
    }

    @Test
    func `different cancel targets compare unequal`() {
        let a: Kernel.Completion.Submission.Opcode = .cancel(target: 1)
        let b: Kernel.Completion.Submission.Opcode = .cancel(target: 2)
        #expect(a != b)
    }

    @Test
    func `different opcode variants compare unequal`() {
        let a: Kernel.Completion.Submission.Opcode = .noOperation
        let b: Kernel.Completion.Submission.Opcode = .close
        #expect(a != b)
    }

    @Test
    func `read opcodes with matching fields compare equal`() {
        let address: Memory.Address = 0x1000
        let length: Memory.Address.Count = 256
        let a: Kernel.Completion.Submission.Opcode = .read(
            address: address,
            length: length,
            offset: 64
        )
        let b: Kernel.Completion.Submission.Opcode = .read(
            address: address,
            length: length,
            offset: 64
        )
        #expect(a == b)
    }

    @Test
    func `read opcode with nil offset differs from read with zero offset`() {
        let address: Memory.Address = 0x1000
        let length: Memory.Address.Count = 256
        let streamMode: Kernel.Completion.Submission.Opcode = .read(
            address: address,
            length: length,
            offset: nil
        )
        let positional: Kernel.Completion.Submission.Opcode = .read(
            address: address,
            length: length,
            offset: 0
        )
        #expect(streamMode != positional)
    }
}

// MARK: - Exhaustiveness

extension Kernel.Completion.Submission.Opcode.Test.Exhaustiveness {
    /// Switch over every variant — a new case without a case branch here
    /// fails to compile.
    ///
    /// `.readiness` is absent on Windows by design — see the
    /// `#if !os(Windows)` gate on the case declaration in
    /// Sources/Kernel Completion/Kernel.Completion.Submission.Opcode.swift —
    /// so this exhaustiveness check (which lists every variant by name) is
    /// gated to match.
    #if !os(Windows)
        @Test
        func `switch covers every variant`() {
            let address: Memory.Address = 0x10
            let length: Memory.Address.Count = 1
            let variants: [Kernel.Completion.Submission.Opcode] = [
                .noOperation,
                .read(address: address, length: length, offset: nil),
                .write(address: address, length: length, offset: nil),
                .close,
                .accept,
                .connect(address: address, length: length),
                .send(address: address, length: length),
                .receive(address: address, length: length),
                .cancel(target: 1),
                .synchronize,
                .readiness(events: [.read]),
            ]
            var seen = 0
            for opcode in variants {
                switch opcode {
                case .noOperation, .close, .accept, .synchronize:
                    seen += 1

                case .read, .write, .connect, .send, .receive:
                    seen += 1

                case .cancel, .readiness:
                    seen += 1
                }
            }
            #expect(seen == variants.count)
        }
    #endif
}

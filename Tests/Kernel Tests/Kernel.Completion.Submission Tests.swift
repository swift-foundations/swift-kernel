//
//  Kernel.Completion.Submission Tests.swift
//  swift-kernel-primitives
//

// `Submission.Opcode.readiness` carries `Kernel.Event.Interest`, which the
// vocabulary hoist moved into the `Kernel Event` target. `Kernel_Completion`
// does not re-export it, so the declaring module is imported per-file
// (#MemberImportVisibility).
import Kernel_Event
import Tagged_Primitives_Standard_Library_Integration
import Testing

#if os(Windows)
    // `Kernel.File.Offset` is declared in the L3 Windows_Kernel_File module,
    // which `Kernel_Completion`'s exports do not re-export — imported
    // per-file (#MemberImportVisibility), matching the idiom used in
    // Sources/Kernel Completion/Kernel.Completion.Submission.Opcode.swift.
    public import Windows_Kernel_File
#endif

@testable import Kernel_Completion

extension Kernel.Completion.Submission {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

// MARK: - Unit Tests

extension Kernel.Completion.Submission.Test.Unit {
    @Test
    func `init with nop uses defaults`() {
        let token: Kernel.Completion.Token = 42
        let sub = Kernel.Completion.Submission(opcode: .noOperation, token: token)

        #expect(sub.token == 42)
        #expect(sub.opcode == .noOperation)
        #expect(sub.flags == [])
        #expect(sub.bufferGroup == .none)
    }

    @Test
    func `cancel opcode carries target token`() {
        let cancelOwn: Kernel.Completion.Token = 7
        let target: Kernel.Completion.Token = 42
        let sub = Kernel.Completion.Submission(
            opcode: .cancel(target: target),
            token: cancelOwn
        )

        #expect(sub.token == cancelOwn)
        guard case .cancel(let recoveredTarget) = sub.opcode else {
            Issue.record("expected .cancel opcode, got \(sub.opcode)")
            return
        }
        #expect(recoveredTarget == target)
    }

    @Test
    func `read opcode carries address length and optional offset`() {
        let address: Memory.Address = 0x1000
        let length: Memory.Address.Count = 4096
        let offset: Kernel.File.Offset = 64
        let token: Kernel.Completion.Token = 99

        let sub = Kernel.Completion.Submission(
            opcode: .read(address: address, length: length, offset: offset),
            token: token
        )

        #expect(sub.token == 99)
        guard case .read(let a, let l, let o) = sub.opcode else {
            Issue.record("expected .read opcode, got \(sub.opcode)")
            return
        }
        #expect(a == address)
        #expect(l == length)
        #expect(o == offset)
    }

    @Test
    func `read opcode with nil offset signals stream mode`() {
        let address: Memory.Address = 0x2000
        let length: Memory.Address.Count = 512

        let sub = Kernel.Completion.Submission(
            opcode: .read(address: address, length: length, offset: nil),
            token: .zero
        )

        guard case .read(_, _, let offset) = sub.opcode else {
            Issue.record("expected .read opcode")
            return
        }
        #expect(offset == nil)
    }

    // `.readiness` is absent on Windows by design — see the `#if !os(Windows)`
    // gate on the case declaration in
    // Sources/Kernel Completion/Kernel.Completion.Submission.Opcode.swift.
    #if !os(Windows)
        @Test
        func `poll opcode carries descriptor interest`() {
            let interest: Kernel.Event.Interest = [.read]
            let sub = Kernel.Completion.Submission(
                opcode: .readiness(events: interest),
                token: 1
            )

            guard case .readiness(let events) = sub.opcode else {
                Issue.record("expected .readiness opcode")
                return
            }
            #expect(events == interest)
        }
    #endif

    @Test
    func `fields are mutable`() {
        let token: Kernel.Completion.Token = 1
        var sub = Kernel.Completion.Submission(opcode: .noOperation, token: token)

        sub.opcode = .close
        #expect(sub.opcode == .close)

        sub.flags = .init(rawValue: 0xF)
        #expect(sub.flags.rawValue == 0xF)
    }
}

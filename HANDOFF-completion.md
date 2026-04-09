# Handoff: Redesign Kernel Completion from First Principles

> To resume: read this file, then read the Kernel Event files as the reference
> implementation. Explore the L1 io_uring primitives. Read the research docs.
> Run /collaborative-discussion to converge on the open design questions before
> implementing. Load /implementation and /code-surface. Ask if anything is unclear.

## Goal

Redesign `Kernel.Completion` (proactor witness) from first principles to the same
quality bar as the just-completed `Kernel.Event` (reactor witness). This is NOT a
mechanical find-and-replace — the proactor paradigm has its own design questions
that need resolution via collaborative discussion before coding.

## Process (Follow This Order)

This is the same process that produced Kernel Event. Each step is mandatory.

### Step 1: Explore

Read the Kernel Event reference implementation (the template):
- `Sources/Kernel Event/Kernel.Event.Driver.swift` — `~Copyable` witness, init in body, normative doc comments, three-boundary model
- `Sources/Kernel Event/Kernel.Event.Source+Kqueue.swift` — State class holds L1 struct, instance methods, zero SPI, helper extraction
- `Sources/Kernel Event/Kernel.Event.Source.swift` — `~Copyable` resource, `consuming` init

Read the current Completion code:
- `Sources/Kernel Completion/Kernel.Completion.Driver.swift` — current witness
- `Sources/Kernel Completion/Kernel.Completion.swift` — current resource
- `Sources/Kernel Completion/Kernel.Completion+IOUring.swift` — current backend

Read the L1 io_uring primitives:
- `swift-primitives/swift-linux-primitives/Sources/Linux Kernel IO Uring Primitives/`

Read the research:
- `swift-kernel/Research/unified-completion-api-design.md`
- `swift-io/Research/io-uring-integration-architecture.md`

### Step 2: Research Document

Write a research document at `Research/kernel-completion-driver-redesign.md` per
/research-process. Analyze the open design questions below. This is Tier 2 (cross-package,
reversible but precedent-adjacent).

### Step 3: Collaborative Discussion

Run /collaborative-discussion to converge on the open design questions. The Event
target's discussion converged in 3 rounds. Expect similar scope.

### Step 4: Implement

Two commits, doc comments written first:
- **Commit A**: L3 implementation against current L1 API
- **Commit B**: L1 additions (wakeup, `@safe`, instance method audit) + L3 simplification

### Step 5: Audit

Run 4 parallel audit agents:
- /implementation, /code-surface, /platform, /memory-safety

Fix all findings. Expected: zero violations, zero SPI in L3.

## Open Design Questions (Must Resolve Before Coding)

These are the Completion-specific questions that need /collaborative-discussion.
They are NOT answered by the Event pattern — the proactor paradigm is different.

### Q1: Callback Drain Semantics

The research proposes `drain(_ visitor: (Event) -> Void) -> Int`. But:
- Can the visitor throw? If so, what happens to unvisited CQEs? Are they lost?
- Is the Event `borrowing` or `consuming` in the visitor? (Event is currently
  Copyable/Sendable, but if it ever becomes ~Copyable for zero-copy buffer
  references, the answer matters now.)
- What about multishot operations (one SQE → N CQEs with `IORING_CQE_F_MORE`)?
  The visitor sees N events. Does the driver need to track multishot state, or
  is that the caller's responsibility?
- Should drain return the count of events visited, or the count of CQEs consumed
  (different if the visitor short-circuits)?

### Q2: Descriptor Ownership

Currently `Completion` exposes `descriptor` via `@_spi(Internal)` and passes it
to every Driver closure. In the Event pattern, the descriptor is absorbed into the
State class and never exposed. But Completion has a complication:

- The `notification` fd (eventfd registered with io_uring) must be accessible to
  `IO.Event.Loop` for epoll registration. This is how the single-thread model works:
  epoll watches the eventfd, io_uring signals it on completion.
- If `descriptor` is absorbed into State, how does `notification` reach the Loop?
- Options: (a) public `notification: Int32` on Completion, (b) wakeup method on
  L1 returns both Channel + notification fd, (c) notification is a separate concern
  from the Driver witness.

### Q3: Flush as Witness Operation

Event has no equivalent to `flush`. In io_uring, `submit` writes to shared memory
(SQ ring), then `flush` calls `io_uring_enter` to notify the kernel. Is flush:
- A Driver witness operation (closure in the struct)?
- A direct L1 instance method call through the State class?
- Both (witness wraps L1 with common infrastructure)?

The answer affects whether the witness has 3 or 4 operational closures.

### Q4: Token Lifecycle and Staleness

Event has staleness suppression: poll results are filtered by registry membership.
Does Completion need equivalent token validation?

- io_uring returns CQEs with a `user_data` field (our Token). If a submission is
  cancelled, does the CQE still arrive? (Yes — with `-ECANCELED` result.)
- Should the Driver filter out CQEs for unknown tokens? Or is every CQE valid by
  construction (the caller submitted it, the kernel completed it)?
- Multishot complicates this: a token persists across multiple CQEs until the
  terminal one (without `IORING_CQE_F_MORE`).

### Q5: Three-Boundary Model for Proactor

Event's model: backend (translation) → driver (staleness) → caller (consumption).

What's the Completion equivalent?
- Backend: raw CQE → `Kernel.Completion.Event` (translation). Clear.
- Driver: token validation? Multishot tracking? Or nothing — all CQEs are valid?
- Caller: consumes events, resolves continuations.

If the driver boundary has no filtering (unlike Event's staleness suppression),
the three-boundary model simplifies to two boundaries. Is that correct, or should
the driver layer add value (e.g., multishot state tracking, overflow detection)?

### Q6: IOCP Stub Scope

How much of the IOCP backend should be designed now?
- Just the factory signature? (`Completion.iocp()`)
- The witness operation signatures? (Do they match io_uring's, or does IOCP need
  different operations — e.g., no flush because IOCP submits directly?)
- Should the witness surface be designed to accommodate both, or should IOCP get
  its own witness shape?

## Current State

- **17 files** in `Sources/Kernel Completion/`
- **Witness pattern**: Already correct (struct of closures)
- **Resource**: `Kernel.Completion` is `~Copyable`, not Sendable — correct
- **Driver**: `Kernel.Completion.Driver` is **Copyable** — should be `~Copyable`
- **Backend**: `Kernel.Completion+IOUring.swift` (~400 LOC) works but has SPI, unsafe, allocation issues
- **L1 io_uring**: Already a `~Copyable` struct — no enum→struct restructure needed
- **Research**: `Research/unified-completion-api-design.md` (IN_PROGRESS)

## Known Issues in Current Code

1. **Driver is Copyable** — silently aliases shared Ring state. Must be `~Copyable`.
2. **`descriptor` exposed via SPI** — should be absorbed into State class.
3. **Harvest allocates** — `inout [Event]` array. Callback drain eliminates this.
4. **SPI in L3** — multiple `@_spi(Syscall)` imports. Target: zero.
5. **Unsafe without `@unsafe`** — `fill()` method does pointer reconstruction without marking.
6. **No `@safe` on L1 io_uring** — missing annotation on the struct.
7. **No wakeup method on L1** — eventfd creation + registration not encapsulated.
8. **Init in extension** — should be in type body per [API-IMPL-008].

## Validated Design Directions (from Event — apply here too)

These are settled — not up for debate:
1. `~Copyable` Driver enforces single-ownership at the type level
2. State class local to factory (inside `iouring()`)
3. `package` visibility for Driver closures and init
4. Thread-confined, no Mutex/Atomic — plain mutable state after `sending` transfer
5. Normative doc comments as specification, written first
6. Backend-local helpers stay file-private
7. L1 instance methods, L3 uses them. Statics take `borrowing Self`.
8. Zero `@_spi(Syscall)` in L3

## Architecture Symmetry (Reactor vs Proactor)

| Aspect | Kernel.Event (reactor, done) | Kernel.Completion (proactor, TODO) |
|--------|-----------------------------|------------------------------------|
| Resource | `Source: ~Copyable` | `Completion: ~Copyable` (already) |
| Driver | `Driver: ~Copyable` | `Driver` → make `~Copyable` |
| Operations | register, modify, deregister, arm, poll, close | submit, flush(?), drain, close |
| Batch I/O | `poll(deadline:into:) → Int` | `harvest → drain(visitor:) → Int` |
| State | Local class holds L1 struct + scratch | Ring class holds L1 struct |
| L1 type | `Kernel.Kqueue` / `Kernel.Event.Poll` | `Kernel.IO.Uring` (already ~Copyable) |
| Wakeup | `kq.wakeup()` / `epoll.wakeup(eventfd:)` | Add to L1 |
| Staleness | Registry membership filter | Token validation? (open question) |
| SPI in L3 | Zero | Currently uses SPI → eliminate |

## L1 io_uring: What Needs Adding

Already a `~Copyable` struct — no restructure needed. But needs:

1. **Wakeup method**: Encapsulate eventfd creation + io_uring registration + raw fd capture
2. **`@safe` annotation**: Safe API boundary marker
3. **Instance method audit**: Verify statics vs instance method split matches kqueue/epoll pattern
4. **Statics take `borrowing Self`**: Same type-safety improvement as kqueue/epoll

Location: `/Users/coen/Developer/swift-primitives/swift-linux-primitives/Sources/Linux Kernel IO Uring Primitives/`

## IOCP (Windows) — Future Scope

Design question Q6 above. At minimum, stub the factory. Full implementation
requires Windows platform primitives (not yet in the ecosystem).

## Constraints

- Swift 6.3: `~Copyable` deferred init inside `do throws(E) {}` triggers compiler bug
- `Kernel.IO.Uring` is already `~Copyable, Sendable` — no restructure needed
- `Kernel.Completion.Token` is `Tagged<Kernel.Completion, UInt64>` — use `.map { }.retag()`
- Thread-confined after `sending` transfer — no Mutex/Atomic needed
- Callback drain must work if Event ever becomes `~Copyable`
- Linux-only for now (IOCP is future)
- Build verification: macOS (cross-compilation) + Linux Docker Swift 6.3

## Files to Read (Exploration Phase)

### Reference (Kernel Event — the template)
- `Sources/Kernel Event/Kernel.Event.Driver.swift`
- `Sources/Kernel Event/Kernel.Event.Source+Kqueue.swift`
- `Sources/Kernel Event/Kernel.Event.Source.swift`
- `Sources/Kernel Event/Kernel.Event.Driver.Registration.swift`
- `Sources/Kernel Event/Kernel.Event.Driver.Error.swift`

### Current Completion Code
- `Sources/Kernel Completion/` (all 17 files)

### L1 io_uring
- `swift-primitives/swift-linux-primitives/Sources/Linux Kernel IO Uring Primitives/Linux.Kernel.IO.Uring.swift`
- Submission/Completion queue entry types

### Research
- `Research/unified-completion-api-design.md`
- `swift-io/Research/io-uring-integration-architecture.md`
- `Research/kernel-event-driver-zero-allocation-redesign.md` (the Event design doc)
- `/tmp/kernel-event-witness-design-converged.md` (the Event collaborative discussion outcome)
